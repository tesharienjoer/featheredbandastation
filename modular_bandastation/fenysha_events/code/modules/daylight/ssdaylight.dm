/area
	var/daylight = FALSE
	var/has_virtual_lighting = FALSE

/area/Initialize(mapload)
	. = ..()
	initialize_daylight()

/area/Destroy()
	. = ..()
	remove_daylight()


/area/proc/clear_virtual_lighting()
	if(!has_virtual_lighting)
		return
	var/list/z_offsets = SSmapping.z_level_to_plane_offset
	for (var/area_zlevel in 1 to get_highest_zlevel())
		if(z_offsets[area_zlevel])
			for(var/turf/area_turf as anything in get_turfs_by_zlevel(area_zlevel))
				area_turf.luminosity = 0
	area_has_base_lighting = FALSE
	has_virtual_lighting = FALSE


/area/proc/update_virtual_lighting(intensity = 1)
	if(!has_virtual_lighting)
		return
	var/list/z_offsets = SSmapping.z_level_to_plane_offset
	for (var/area_zlevel in 1 to get_highest_zlevel())
		if(z_offsets[area_zlevel])
			for(var/turf/area_turf as anything in get_turfs_by_zlevel(area_zlevel))
				area_turf.luminosity = intensity

/area/proc/add_virtual_lighting(intensity = 1)
	if(!has_virtual_lighting)
		return
	var/list/z_offsets = SSmapping.z_level_to_plane_offset
	for (var/area_zlevel in 1 to get_highest_zlevel())
		if(z_offsets[area_zlevel])
			for(var/turf/area_turf as anything in get_turfs_by_zlevel(area_zlevel))
				area_turf.luminosity = intensity
	area_has_base_lighting = TRUE
	has_virtual_lighting = TRUE

/area/proc/set_virtual_lighting(intensity = 1)
	if(has_virtual_lighting)
		return
	if(intensity <= 0.2)
		area_has_base_lighting = FALSE
		return
	var/list/z_offsets = SSmapping.z_level_to_plane_offset
	for (var/area_zlevel in 1 to get_highest_zlevel())
		if(z_offsets[area_zlevel])
			for(var/turf/area_turf as anything in get_turfs_by_zlevel(area_zlevel))
				area_turf.luminosity = intensity * 2
		else
			for(var/turf/area_turf as anything in get_turfs_by_zlevel(area_zlevel))
				area_turf.luminosity = 0
	area_has_base_lighting = TRUE
	has_virtual_lighting = TRUE

/area/proc/initialize_daylight()
	if(daylight)
		SSdaylight.daylight_areas += src
		SSdaylight.update_area(src)

/area/proc/remove_daylight()
	if(daylight)
		SSdaylight.daylight_areas -= src

/datum/daylight_phase
	var/name = "Phase"
	var/color = "#ffffff"
	var/start_time = 0
	var/target_intensity = 1

/datum/daylight_phase/dawn
	name = "Dawn"
	color = "#31211b"
	start_time = 4 HOURS
	target_intensity = 0.2

/datum/daylight_phase/sunrise
	name = "Sunrise"
	color = "#F598AB"
	start_time = 5 HOURS
	target_intensity = 0.55

/datum/daylight_phase/daytime
	name = "Daytime"
	color = "#FFFFFF"
	start_time = 5.5 HOURS
	target_intensity = 1

/datum/daylight_phase/sunset
	name = "Sunset"
	color = "#ff8a63"
	start_time = 19 HOURS
	target_intensity = 0.45

/datum/daylight_phase/dusk
	name = "Dusk"
	color = "#2b2842"
	start_time = 19.5 HOURS
	target_intensity = 0.18

/datum/daylight_phase/midnight
	name = "Midnight"
	color = "#101c3b"
	start_time = 20 HOURS
	target_intensity = 0.08

SUBSYSTEM_DEF(daylight)
	name = "Daylight Controller"
	wait = 1 SECONDS
	runlevels = RUNLEVEL_GAME
	dependencies = list(
		/datum/controller/subsystem/mapping,
		/datum/controller/subsystem/lighting
	)

	var/static/list/daylight_areas = list()
	var/static/list/obj/effect/light_emitter/daylight/all_emitters = list()

	var/current_intensity = 1
	var/current_color = "#ffffff"
	var/list/current_rgb = list(255, 255, 255)

	var/target_intensity = 1
	var/target_color = "#ffffff"
	var/start_intensity = 1
	var/start_color = "#ffffff"
	var/transition_steps = 0
	var/const/TRANSITION_STEPS = 6

	var/daylight_fraction = 0.77

	var/delta_cycle_progress = 0.05
	var/cycle_locked = FALSE
	var/time_locked = FALSE
	var/manual_time = -1

	var/falshing = FALSE
	var/setup_queue = list()
	var/setup_running = FALSE

	var/last_cycle_progress = -1
	var/datum/daylight_phase/current_phase
	var/datum/daylight_phase/next_phase
	var/list/daylight_phases = list(
		new /datum/daylight_phase/dawn(),
		new /datum/daylight_phase/sunrise(),
		new /datum/daylight_phase/daytime(),
		new /datum/daylight_phase/sunset(),
		new /datum/daylight_phase/dusk(),
		new /datum/daylight_phase/midnight()
	)
	var/last_phase_name

	var/mob_visual_update_cooldown = 3 SECONDS
	COOLDOWN_DECLARE(mob_visual_cd)

	var/list/phase_particle_weights = list(
		"Dawn" = list(
			/particles/daylight_weather/rain = 5,
			/particles/daylight_weather/mist = 3,
		),
		"Sunrise" = list(
			/particles/daylight_weather/mist = 6,
			/particles/daylight_weather/rain = 2,
		),
		"Daytime" = list(
			/particles/daylight_weather/dust = 7,
			/particles/daylight_weather/mist = 2,
		),
		"Sunset" = list(
			/particles/daylight_weather/rain = 5,
			/particles/daylight_weather/dust = 2,
		),
		"Dusk" = list(
			/particles/daylight_weather/snow = 5,
			/particles/daylight_weather/mist = 3,
		),
		"Midnight" = list(
			/particles/daylight_weather/snow = 7,
			/particles/daylight_weather/mist = 2,
		),
	)
	var/current_particle_weather = /particles/daylight_weather/mist
	var/visual_weather_override = "auto"
	var/visual_weather_strength = 0
	var/target_visual_weather_strength = 0

	var/daylight_update_cooldown = 2 MINUTES
	// Daylight cycle in minutes
	var/daylight_cycle = 60
	COOLDOWN_DECLARE(daylight_update_cd)

/datum/controller/subsystem/daylight/Initialize()
	SSticker.station_time_rate_multiplier = 1440 / daylight_cycle

	current_rgb = hex2rgb(current_color)
	var/initial_progress = get_cycle_progress()
	last_cycle_progress = initial_progress
	resolve_phase()
	var/list/phase_state = get_phase_light_state()
	current_intensity = phase_state["intensity"]
	current_color = phase_state["color"]
	update_current(current_intensity, current_color)

	return SS_INIT_SUCCESS

/datum/controller/subsystem/daylight/proc/update_area(area/A)
	if(!istype(A) || QDELETED(A) || !A.daylight)
		return
	A.set_virtual_lighting(round(current_intensity * 255, 1))

/datum/controller/subsystem/daylight/proc/register_emitter(obj/effect/light_emitter/daylight/emitter)
	if(!emitter || QDELETED(emitter) || (emitter in all_emitters))
		return
	all_emitters += emitter
	emitter.apply_current_state()

/datum/controller/subsystem/daylight/proc/unregister_emitter(obj/effect/light_emitter/daylight/emitter)
	all_emitters -= emitter

/datum/controller/subsystem/daylight/proc/update_all_areas()
	if(setup_running)
		return
	setup_running = TRUE
	for(var/area/A in daylight_areas)
		update_area(A)
		CHECK_TICK
	setup_running = FALSE

/datum/controller/subsystem/daylight/proc/set_target(intensity, color)
	target_intensity = clamp(intensity, 0, 1)
	target_color = color
	start_intensity = current_intensity
	start_color = current_color
	transition_steps = TRANSITION_STEPS

/datum/controller/subsystem/daylight/proc/set_intensity_and_color(intensity = target_intensity, color = target_color, force = FALSE)
	if(force)
		transition_steps = 0
		update_current(intensity, color)
	else
		set_target(intensity, color)

/datum/controller/subsystem/daylight/proc/update_current(intensity, color)
	var/changed = abs(current_intensity - intensity) > 0.001 || current_color != color
	if(!changed)
		return

	current_intensity = intensity
	current_color = color
	current_rgb = hex2rgb(color)

	if(changed)
		update_all_areas()
		for(var/obj/effect/light_emitter/daylight/E in all_emitters)
			E.apply_current_state()
		SEND_SIGNAL(src, COMSIG_DAYLIGHT_UPDATED, current_intensity, current_color)

/datum/controller/subsystem/daylight/proc/get_cycle_progress()
	return station_time() / (24 HOURS)

/datum/controller/subsystem/daylight/proc/resolve_phase()
	var/time_now = station_time()
	var/datum/daylight_phase/new_current
	var/datum/daylight_phase/new_next

	for(var/i in 1 to length(daylight_phases))
		var/datum/daylight_phase/phase = daylight_phases[i]
		if(time_now >= phase.start_time)
			new_current = phase
			new_next = (i == length(daylight_phases)) ? daylight_phases[1] : daylight_phases[i + 1]

	if(!new_current)
		new_current = daylight_phases[length(daylight_phases)]
		new_next = daylight_phases[1]

	current_phase = new_current
	next_phase = new_next

/datum/controller/subsystem/daylight/proc/get_phase_progress()
	if(!current_phase || !next_phase)
		return 0

	var/full_day = 24 HOURS
	var/duration = next_phase.start_time - current_phase.start_time
	if(duration <= 0)
		duration += full_day

	var/elapsed = station_time() - current_phase.start_time
	if(elapsed < 0)
		elapsed += full_day

	if(duration <= 0)
		return 0

	return clamp(elapsed / duration, 0, 1)

/datum/controller/subsystem/daylight/proc/get_phase_light_state()
	resolve_phase()
	var/mix = get_phase_progress()
	var/color = color_interpolate(current_phase.color, next_phase.color, mix)
	var/intensity = lerp(current_phase.target_intensity, next_phase.target_intensity, mix)
	if(current_phase?.name == "Dusk" || current_phase?.name == "Midnight" || next_phase?.name == "Midnight")
		// Preserve atmospheric moonlight at night so blacks are not crushed.
		var/moonlight_ratio = clamp(1 - intensity, 0, 1)
		color = color_interpolate(color, "#6f86b6", moonlight_ratio * 0.4)
		intensity = max(intensity, 0.06)
	return list("color" = color, "intensity" = clamp(intensity, 0, 1))

/datum/controller/subsystem/daylight/proc/get_manual_light_color(value)
	var/datum/daylight_phase/day_phase = daylight_phases[3]
	var/datum/daylight_phase/night_phase = daylight_phases[6]
	return color_interpolate(night_phase.color, day_phase.color, clamp(value, 0, 1))

/datum/controller/subsystem/daylight/proc/get_auto_weather_particle_type()
	resolve_phase()
	var/list/particle_weights = phase_particle_weights[current_phase?.name]
	if(!length(particle_weights))
		return /particles/daylight_weather/mist
	return pick_weight(particle_weights)

/datum/controller/subsystem/daylight/proc/get_weather_particle_type()
	if(visual_weather_override == "rain")
		return /particles/daylight_weather/rain
	if(visual_weather_override == "snow")
		return /particles/daylight_weather/snow
	if(visual_weather_override == "dust")
		return /particles/daylight_weather/dust
	if(visual_weather_override == "mist")
		return /particles/daylight_weather/mist
	if(visual_weather_override == "none")
		return null
	var/next_auto = get_auto_weather_particle_type()
	if(next_auto)
		current_particle_weather = next_auto
	return current_particle_weather

/datum/controller/subsystem/daylight/proc/update_mob_visuals()
	var/particle_type = get_weather_particle_type()
	target_visual_weather_strength = clamp((1 - current_intensity) * 1.15, 0.05, 1)
	if(visual_weather_override == "none")
		target_visual_weather_strength = 0
	visual_weather_strength = lerp(visual_weather_strength, target_visual_weather_strength, 0.35)
	var/overlay_alpha = round(clamp((1 - current_intensity) * 140, 20, 140), 1)

	for(var/mob/living/player as anything in GLOB.alive_player_list)
		if(!player.client)
			continue
		var/datum/preferences/prefs = player.client?.prefs
		var/use_daylight_tint = prefs ? prefs.read_preference(/datum/preference/toggle/daylight_tint_fx) : TRUE
		var/use_daylight_particles = prefs ? prefs.read_preference(/datum/preference/toggle/daylight_particle_fx) : TRUE

		var/area/A = get_area(player)
		if(!A || !A.daylight)
			player.clear_fullscreen("daylight_tint", 2)
			player.clear_fullscreen("daylight_particles", 2)
			continue

		if(!use_daylight_tint)
			player.clear_fullscreen("daylight_tint", 2)
		else
			var/atom/movable/screen/fullscreen/daylight_tint/tint_overlay = player.overlay_fullscreen("daylight_tint", /atom/movable/screen/fullscreen/daylight_tint)
			if(tint_overlay)
				animate(tint_overlay, alpha = overlay_alpha, color = current_color, time = max(1, round(mob_visual_update_cooldown / (1 SECONDS), 1)))

		if(!use_daylight_particles)
			player.clear_fullscreen("daylight_particles", 2)
		else
			var/atom/movable/screen/fullscreen/daylight_particles/particle_overlay = player.overlay_fullscreen("daylight_particles", /atom/movable/screen/fullscreen/daylight_particles)
			if(!particle_overlay)
				continue
			if(!particle_type)
				animate(particle_overlay, alpha = 0, time = max(1, round(mob_visual_update_cooldown / (1 SECONDS), 1)))
				continue
			if(!particle_overlay.particles || particle_overlay.current_particle_type != particle_type)
				particle_overlay.particles = new particle_type()
				particle_overlay.current_particle_type = particle_type
			var/target_particle_alpha = round(clamp(visual_weather_strength * 160, 0, 170), 1)
			animate(particle_overlay, alpha = target_particle_alpha, color = current_color, time = max(1, round(mob_visual_update_cooldown / (1 SECONDS), 1)))

/datum/controller/subsystem/daylight/fire()
	if(transition_steps > 0)
		var/fraction = 1 - (transition_steps - 1) / TRANSITION_STEPS
		var/new_intensity = lerp(start_intensity, target_intensity, fraction)
		var/new_color = color_interpolate(start_color, target_color, fraction)
		update_current(new_intensity, new_color)
		transition_steps--

	if(!COOLDOWN_FINISHED(src, daylight_update_cd))
		return
	COOLDOWN_START(src, daylight_update_cd, daylight_update_cooldown)

	var/auto_cycle = (manual_time < 0 && !time_locked && !cycle_locked)
	var/cycle_progress = get_cycle_progress()

	if(auto_cycle)
		if(last_cycle_progress < 0)
			last_cycle_progress = cycle_progress
		else
			if(cycle_progress < last_cycle_progress - 0.01)
				message_admins("A new day has dawned on the station!")
				SEND_SIGNAL(src, COMSIG_DAYLIGHT_NEW_DAY)
				SEND_SIGNAL(src, COMSIG_DAYLIGHT_DAY_START)

			else if(last_cycle_progress < daylight_fraction && cycle_progress >= daylight_fraction)
				message_admins("Night has fallen on the station.")
				SEND_SIGNAL(src, COMSIG_DAYLIGHT_NIGHT_START)

	if(!auto_cycle)
		return
	if(abs(cycle_progress - last_cycle_progress) < delta_cycle_progress)
		return
	resolve_phase()
	var/current_phase_name = current_phase ? current_phase.name : null
	if(current_phase_name != last_phase_name)
		last_phase_name = current_phase_name

	var/list/phase_state = get_phase_light_state()
	set_target(phase_state["intensity"], phase_state["color"])
	last_cycle_progress = cycle_progress

	if(COOLDOWN_FINISHED(src, mob_visual_cd))
		update_mob_visuals()
		COOLDOWN_START(src, mob_visual_cd, mob_visual_update_cooldown)

/datum/controller/subsystem/daylight/proc/flash(color, duration = 10 SECONDS, transition_time = 2 SECONDS, areas)
	set waitfor = FALSE
	if(falshing)
		return
	falshing = TRUE
	if(!areas)
		areas = daylight_areas.Copy()
	var/trainstation_wait = 0.1 SECONDS
	var/orig_target_intensity = target_intensity
	var/orig_target_color = target_color
	var/steps_up = round(transition_time / wait, 1)
	var/steps_down = steps_up
	var/hold_steps = round(duration / trainstation_wait, 1) - steps_up - steps_down
	if(hold_steps < 0)
		hold_steps = 0
		steps_down = round((duration / wait) / 2, 1)
		steps_up = steps_down

	set_target(1, color)
	for(var/i in 1 to steps_up)
		fire()
		sleep(trainstation_wait)
		CHECK_TICK

	for(var/i in 1 to hold_steps)
		sleep(duration / hold_steps)
		CHECK_TICK

	set_target(orig_target_intensity, orig_target_color)
	for(var/i in 1 to steps_down)
		fire()
		sleep(trainstation_wait)
		CHECK_TICK
	falshing = FALSE

/proc/hex2rgb(hex)
	if(!hex)
		return list(255, 255, 255)

	if(copytext(hex, 1, 2) == "#")
		hex = copytext(hex, 2)

	var/len = length(hex)
	if(len == 3)
		hex = "[copytext(hex,1,2)][copytext(hex,1,2)][copytext(hex,2,3)][copytext(hex,2,3)][copytext(hex,3,4)][copytext(hex,3,4)]"

	if(length(hex) != 6)
		return list(255, 255, 255)

	var/r = hex2num(copytext(hex, 1, 3))
	var/g = hex2num(copytext(hex, 3, 5))
	var/b = hex2num(copytext(hex, 5, 7))

	return list(r, g, b)


/proc/color_interpolate(color1, color2, ratio)
	var/list/c1 = hex2rgb(color1)
	var/list/c2 = hex2rgb(color2)
	var/r = round(c1[1] + (c2[1] - c1[1]) * ratio, 1)
	var/g = round(c1[2] + (c2[2] - c1[2]) * ratio, 1)
	var/b = round(c1[3] + (c2[3] - c1[3]) * ratio, 1)
	return rgb(r, g, b)


ADMIN_VERB(set_daylight_time, R_ADMIN, "Set Daylight Time (0-1)", "Force daylight intensity or return to auto", ADMIN_CATEGORY_EVENTS)
	if(!check_rights(R_ADMIN))
		return

	var/value = input(usr, "Set forced intensity (0 = night, 1 = day, -1 = auto)", "Daylight Control", -1) as num|null
	if(isnull(value))
		return

	value = clamp(value, -1, 1)
	SSdaylight.manual_time = (value < 0 ? -1 : value)
	SSdaylight.time_locked = (value >= 0)
	SSdaylight.cycle_locked = (value >= 0)

	if(value >= 0)
		var/color = SSdaylight.get_manual_light_color(value)
		SSdaylight.set_intensity_and_color(value, color, FALSE)

	log_admin("[key_name(usr)] set daylight time to [value == -1 ? "AUTO" : value]")
	message_admins(span_adminnotice("[key_name_admin(usr)] set daytime: [value == -1 ? "auto" : value]"))

ADMIN_VERB(toggle_daylight_cycle_lock, R_ADMIN, "Toggle Daylight Cycle Lock", "Lock/unlock automatic day-night cycle", ADMIN_CATEGORY_EVENTS)
	if(!check_rights(R_ADMIN))
		return

	SSdaylight.cycle_locked = !SSdaylight.cycle_locked
	if(!SSdaylight.cycle_locked)
		SSdaylight.time_locked = FALSE
		SSdaylight.manual_time = -1

	log_admin("[key_name(usr)] [SSdaylight.cycle_locked ? "locked" : "unlocked"] daylight cycle")
	message_admins(span_adminnotice("[key_name_admin(usr)] [SSdaylight.cycle_locked ? "locked" : "unlocked"] daylight cycle"))

ADMIN_VERB(flash_daylight, R_ADMIN, "Flash Daylight", "Temporarily flash areas with a color", ADMIN_CATEGORY_EVENTS)
	if(!check_rights(R_ADMIN))
		return

	var/color = input(usr, "Choose flash color", "Flash Color") as color|null
	if(isnull(color))
		return

	var/duration = input(usr, "Set flash duration in seconds", "Flash Duration", 10) as num|null
	if(isnull(duration))
		return

	var/transition_time = input(usr, "Set transition time in seconds", "Transition Time", 2) as num|null
	if(isnull(transition_time))
		return

	SSdaylight.flash(color, duration SECONDS, transition_time SECONDS)

	log_admin("[key_name(usr)] triggered daylight flash with color [color] for [duration] seconds")
	message_admins(span_adminnotice("[key_name_admin(usr)] triggered daylight flash with color [color] for [duration] seconds"))

ADMIN_VERB(open_daylight_control_panel, R_ADMIN, "Open Daylight Control Panel", "Open UI panel for day/night and weather control", ADMIN_CATEGORY_EVENTS)
	if(!check_rights(R_ADMIN))
		return
	var/datum/daylight_control_panel/panel = new
	panel.ui_interact(usr)

/datum/daylight_control_panel/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/daylight_control_panel/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "DaylightControl", "Daylight Control")
		ui.open()

/datum/daylight_control_panel/ui_data(mob/user)
	var/list/data = list()
	data["cycle_locked"] = SSdaylight.cycle_locked
	data["time_locked"] = SSdaylight.time_locked
	data["manual_time"] = SSdaylight.manual_time
	data["daylight_cycle"] = SSdaylight.daylight_cycle
	data["current_intensity"] = SSdaylight.current_intensity
	data["current_color"] = SSdaylight.current_color
	data["current_phase"] = SSdaylight.current_phase ? SSdaylight.current_phase.name : "Unknown"
	data["active_weather_count"] = (SSdaylight.visual_weather_override == "none") ? 0 : 1
	data["visual_weather_mode"] = SSdaylight.visual_weather_override
	return data

/datum/daylight_control_panel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!check_rights_for(ui.user?.client, R_ADMIN))
		return

	switch(action)
		if("set_manual")
			var/value = text2num(params["value"])
			value = clamp(value, -1, 1)
			SSdaylight.manual_time = (value < 0 ? -1 : value)
			SSdaylight.time_locked = (value >= 0)
			SSdaylight.cycle_locked = (value >= 0)
			if(value >= 0)
				var/color = SSdaylight.get_manual_light_color(value)
				SSdaylight.set_intensity_and_color(value, color, FALSE)
			return TRUE

		if("set_cycle_minutes")
			var/new_cycle = clamp(round(text2num(params["value"]), 1), 5, 240)
			SSdaylight.daylight_cycle = new_cycle
			SSticker.station_time_rate_multiplier = 1440 / SSdaylight.daylight_cycle
			return TRUE

		if("toggle_cycle_lock")
			SSdaylight.cycle_locked = !SSdaylight.cycle_locked
			if(!SSdaylight.cycle_locked)
				SSdaylight.time_locked = FALSE
				SSdaylight.manual_time = -1
			return TRUE

		if("set_auto")
			SSdaylight.manual_time = -1
			SSdaylight.time_locked = FALSE
			SSdaylight.cycle_locked = FALSE
			return TRUE

		if("start_weather")
			var/selected = params["weather_type"]
			switch(selected)
				if("rain")
					SSdaylight.visual_weather_override = "rain"
				if("snow")
					SSdaylight.visual_weather_override = "snow"
				if("radiation")
					SSdaylight.visual_weather_override = "dust"
				if("mist")
					SSdaylight.visual_weather_override = "mist"
				if("auto")
					SSdaylight.visual_weather_override = "auto"
			log_admin("[key_name(ui.user)] switched visual weather to [SSdaylight.visual_weather_override] from daylight control panel")
			message_admins(span_adminnotice("[key_name_admin(ui.user)] switched visual weather to [SSdaylight.visual_weather_override] from daylight control panel"))
			return TRUE

		if("stop_weather")
			SSdaylight.visual_weather_override = "none"
			log_admin("[key_name(ui.user)] disabled visual weather from daylight control panel")
			message_admins(span_adminnotice("[key_name_admin(ui.user)] disabled visual weather from daylight control panel"))
			return TRUE

	return FALSE

/datum/preference/toggle/daylight_tint_fx
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "daylight_tint_fx"
	savefile_identifier = PREFERENCE_PLAYER

/datum/preference/toggle/daylight_tint_fx/create_default_value()
	return TRUE

/datum/preference/toggle/daylight_particle_fx
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "daylight_particle_fx"
	savefile_identifier = PREFERENCE_PLAYER

/datum/preference/toggle/daylight_particle_fx/create_default_value()
	return TRUE


/obj/effect/light_emitter
	flags_1 = NO_TURF_MOVEMENT_1

/obj/effect/light_emitter/daylight
	set_luminosity = 2
	set_cap = 0.5
	var/initial_lum = 2
	var/initial_cap = 0.5

/obj/effect/light_emitter/daylight/Initialize(mapload)
	. = ..()
	initial_lum = set_luminosity
	initial_cap = set_cap
	if(SSdaylight)
		SSdaylight.register_emitter(src)

/obj/effect/light_emitter/daylight/proc/apply_current_state()
	if(!SSdaylight)
		return
	var/mult = SSdaylight.current_intensity
	light_power = initial_cap * mult
	light_color = SSdaylight.current_color
	update_light()

/obj/effect/light_emitter/daylight/Destroy()
	if(SSdaylight)
		SSdaylight.unregister_emitter(src)
	return ..()

/datum/element/daylight_overlay
	element_flags = ELEMENT_DETACH_ON_HOST_DESTROY

/datum/element/daylight_overlay/Attach(datum/target)
	. = ..()
	if(!istype(target, /turf))
		return ELEMENT_INCOMPATIBLE

	RegisterSignal(SSdaylight, COMSIG_DAYLIGHT_UPDATED, PROC_REF(update_overlay))

/datum/element/daylight_overlay/Detach(datum/source)
	. = ..()
	UnregisterSignal(SSdaylight, COMSIG_DAYLIGHT_UPDATED)

/datum/element/daylight_overlay/proc/update_overlay(datum/source, intensity, color)
	SIGNAL_HANDLER
	// Virtual light only: no direct overlay injection on turfs.
	if(!istype(source, /datum/controller/subsystem/daylight))
		return

/atom/movable/screen/fullscreen/daylight_tint
	icon = 'icons/hud/screen_gen.dmi'
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	icon_state = "flash"
	plane = LIGHTING_PLANE
	layer = LIGHTING_ABOVE_ALL
	blend_mode = BLEND_MULTIPLY
	show_when_dead = TRUE
	needs_offsetting = FALSE
	alpha = 0

/atom/movable/screen/fullscreen/daylight_particles
	icon = 'icons/hud/screen_gen.dmi'
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	icon_state = "flash"
	plane = WEATHER_PLANE
	layer = FULLSCREEN_LAYER + 1
	blend_mode = BLEND_ADD
	show_when_dead = TRUE
	needs_offsetting = FALSE
	alpha = 0
	var/current_particle_type = /particles/daylight_weather/mist

/particles/daylight_weather
	icon = 'icons/effects/particles/generic.dmi'
	width = 480
	height = 480
	count = 120
	spawning = 0.4
	lifespan = 1.8 SECONDS
	fade = 1.2 SECONDS
	position = generator(GEN_BOX, list(-240, -180, 0), list(240, 240, 0))
	gravity = list(0, -1.3)
	drift = generator(GEN_CIRCLE, 0, 2)
	friction = 0.25

/particles/daylight_weather/rain
	icon_state = list("drop" = 4, "dot" = 1)
	color = "#b0d8ff"
	spawning = 1.2
	count = 200
	lifespan = 1.1 SECONDS
	fade = 0.5 SECONDS
	gravity = list(0, -4.4)
	drift = generator(GEN_CIRCLE, 0, 1)

/particles/daylight_weather/snow
	icon_state = list("dot" = 3, "cross" = 2)
	color = "#f2f7ff"
	spawning = 0.5
	count = 140
	lifespan = 2.6 SECONDS
	fade = 1.4 SECONDS
	gravity = list(0, -1.1)
	drift = generator(GEN_CIRCLE, 0, 3)
	spin = generator(GEN_NUM, -8, 8)

/particles/daylight_weather/dust
	icon_state = list("dot" = 4, "cross" = 1)
	color = "#c59a6f"
	spawning = 0.45
	count = 110
	lifespan = 2.4 SECONDS
	fade = 1.1 SECONDS
	gravity = list(-1.2, -0.4)
	drift = generator(GEN_CIRCLE, 0, 4)
	spin = generator(GEN_NUM, -6, 6)

/particles/daylight_weather/mist
	icon_state = list("dot" = 4)
	color = "#c7d5e8"
	spawning = 0.35
	count = 90
	lifespan = 3 SECONDS
	fade = 1.7 SECONDS
	gravity = list(0, -0.4)
	drift = generator(GEN_CIRCLE, 0, 2)

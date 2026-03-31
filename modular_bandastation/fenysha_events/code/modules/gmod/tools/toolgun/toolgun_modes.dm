/datum/toolgun_mode
	var/name = "Defualt mode"
	var/desc = "Coder button."
	var/mode_key = "generic"
	var/obj/item/toolgun/our_tool
	var/tgui_ui_id = "Toolgun"

/datum/toolgun_mode/proc/on_selected(mob/user)
	to_chat(user, span_notice(desc))

/datum/toolgun_mode/proc/main_act(atom/target, mob/user)

/datum/toolgun_mode/proc/secondnary_act(atom/target, mob/user)

/datum/toolgun_mode/proc/use_act(mob/user)
	ui_interact(user)

/datum/toolgun_mode/ui_state(mob/user)
	return our_tool?.ui_state(user)

/datum/toolgun_mode/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, tgui_ui_id)
		ui.open()

/datum/toolgun_mode/ui_data(mob/user)
	return list(
		"mode_name" = name,
		"mode_desc" = desc,
		"mode_key" = mode_key,
	)

/datum/toolgun_mode/proc/param_to_bool(value)
	if(isnum(value))
		return !!value
	if(istext(value))
		var/value_text = lowertext(trimtext(value))
		return value_text == "1" || value_text == "true" || value_text == "yes" || value_text == "on"
	return FALSE

/datum/toolgun_mode/proc/set_indestructible(atom/target, should_set)
	if(!target || !("resistance_flags" in target.vars))
		return
	if(should_set)
		target.resistance_flags |= INDESTRUCTIBLE
	else
		target.resistance_flags &= ~INDESTRUCTIBLE


/datum/toolgun_mode/spawn_mode
	name = "Spawn mode"
	desc = "Opens object browser and spawns selected object on target."
	mode_key = "spawn"

	/// Path selected in UI.
	var/selected_type_path = "/obj"
	/// The type selected in UI.
	var/selected_type = /obj
	/// Current search query from UI.
	var/current_search = ""
	/// Amount of entries to show in UI.
	var/loaded_limit = 80
	/// How many entries are added per "load more".
	var/page_size = 80
	/// Whether custom color should be applied.
	var/use_custom_color = FALSE
	/// Color to apply on spawned object.
	var/custom_color = "#FFFFFF"
	/// Density value to force on spawn.
	var/custom_density = FALSE
	/// Opacity value to force on spawn.
	var/custom_opacity = FALSE
	/// Whether spawned object should be indestructible.
	var/custom_indestructible = FALSE
	/// Shared static type graph cache.
	var/static/list/cached_type_nodes
	/// Shared static object cache.
	var/static/list/cached_objects

/datum/toolgun_mode/spawn_mode/main_act(atom/target, mob/user)
	if(!selected_type)
		return FALSE
	if(!ispath(selected_type, /obj))
		return FALSE
	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		target_turf = get_turf(user)
	if(!target_turf)
		return FALSE
	var/obj/spawned_object = new selected_type(target_turf)
	if(!spawned_object)
		return FALSE
	if(use_custom_color)
		spawned_object.color = custom_color
	spawned_object.density = custom_density
	spawned_object.opacity = custom_opacity
	set_indestructible(spawned_object, custom_indestructible)
	return TRUE

/datum/toolgun_mode/spawn_mode/ui_static_data(mob/user)
	build_spawn_cache()
	return list(
		"type_nodes" = cached_type_nodes,
	)

/datum/toolgun_mode/spawn_mode/ui_data(mob/user)
	. = ..()
	.["selected_type"] = selected_type_path
	.["search"] = current_search
	.["use_custom_color"] = use_custom_color
	.["custom_color"] = custom_color
	.["custom_density"] = custom_density
	.["custom_opacity"] = custom_opacity
	.["custom_indestructible"] = custom_indestructible

	var/list/visible_entries = list()
	var/match_count = 0
	var/want_limit = loaded_limit
	var/filter_by_search = length(current_search) > 0
	var/normalized_search = lowertext(current_search)

	for(var/list/object_entry as anything in cached_objects)
		var/object_type = object_entry["type"]
		if(selected_type_path != "/obj" && copytext(object_type, 1, length(selected_type_path) + 1) != selected_type_path)
			continue
		if(filter_by_search)
			var/object_name = lowertext("[object_entry["name"]]")
			var/lower_type = lowertext(object_type)
			if(!findtext(object_name, normalized_search) && !findtext(lower_type, normalized_search))
				continue
		match_count++
		if(filter_by_search || match_count <= want_limit)
			visible_entries += list(object_entry)

	.["objects"] = visible_entries
	.["visible_count"] = length(visible_entries)
	.["match_count"] = match_count
	.["has_more"] = !filter_by_search && match_count > want_limit

/datum/toolgun_mode/spawn_mode/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	switch(action)
		if("select_type")
			var/path_to_select = params["path"]
			var/type_to_select = text2path(path_to_select)
			if(type_to_select && ispath(type_to_select, /obj))
				selected_type_path = path_to_select
				selected_type = type_to_select
				loaded_limit = page_size
			return TRUE
		if("set_search")
			current_search = trimtext(params["search"])
			loaded_limit = page_size
			return TRUE
		if("set_custom_color")
			var/new_color = trimtext(params["color"])
			if(length(new_color))
				custom_color = new_color
			return TRUE
		if("pick_custom_color")
			var/chosen_color = tgui_color_picker(usr, "Select spawn color", "Toolgun spawn mode", custom_color)
			if(chosen_color)
				custom_color = chosen_color
			return TRUE
		if("toggle_use_custom_color")
			use_custom_color = !use_custom_color
			return TRUE
		if("toggle_custom_density")
			custom_density = !custom_density
			return TRUE
		if("toggle_custom_opacity")
			custom_opacity = !custom_opacity
			return TRUE
		if("toggle_custom_indestructible")
			custom_indestructible = !custom_indestructible
			return TRUE
		if("load_more")
			if(!length(current_search))
				loaded_limit += page_size
			return TRUE
		if("spawn_here")
			return main_act(get_turf(usr), usr)
	return ..()

/datum/toolgun_mode/spawn_mode/proc/build_spawn_cache()
	if(cached_type_nodes && cached_objects)
		return

	cached_type_nodes = list()
	cached_objects = list()
	for(var/atom/movable/obj_path as anything in subtypesof(/obj))
		var/path_text = "[obj_path]"
		if(!length(path_text))
			continue

		var/list/path_parts = splittext(path_text, "/")
		var/current_path = ""
		var/parent_path = ""
		for(var/path_part in path_parts)
			if(!length(path_part))
				continue
			current_path += "/[path_part]"
			if(!cached_type_nodes[current_path])
				cached_type_nodes[current_path] = list(
					"id" = current_path,
					"parent" = parent_path,
					"name" = path_part,
				)
			parent_path = current_path

		cached_objects += list(list(
			"type" = path_text,
			"name" = initial(obj_path.name),
			"icon" = "[initial(obj_path.icon)]",
			"icon_state" = "[initial(obj_path.icon_state)]",
		))


/datum/toolgun_mode/color_mode
	name = "Color mode"
	desc = "LMB applies selected color. RMB resets target color."
	mode_key = "color"

	var/selected_color = "#FFFFFF"

/datum/toolgun_mode/color_mode/main_act(atom/target, mob/user)
	if(!isobj(target))
		return FALSE
	target.color = selected_color
	return TRUE

/datum/toolgun_mode/color_mode/secondnary_act(atom/target, mob/user)
	if(!isobj(target))
		return FALSE
	target.color = initial(target.color)
	return TRUE

/datum/toolgun_mode/color_mode/ui_data(mob/user)
	. = ..()
	.["selected_color"] = selected_color

/datum/toolgun_mode/color_mode/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	switch(action)
		if("pick_color")
			var/chosen_color = tgui_color_picker(usr, "Select object color", "Toolgun color mode", selected_color)
			if(chosen_color)
				selected_color = chosen_color
			return TRUE
		if("set_color")
			var/new_color = trimtext(params["color"])
			if(length(new_color))
				selected_color = new_color
			return TRUE
	return ..()


/datum/toolgun_mode/resize_mode
	name = "Resize mode"
	desc = "LMB resizes target object. RMB resets scale."
	mode_key = "resize"

	var/scale_value = 1

/datum/toolgun_mode/resize_mode/main_act(atom/target, mob/user)
	if(!isobj(target))
		return FALSE
	var/matrix/new_transform = matrix()
	new_transform.Scale(scale_value, scale_value)
	target.transform = new_transform
	return TRUE

/datum/toolgun_mode/resize_mode/secondnary_act(atom/target, mob/user)
	if(!isobj(target))
		return FALSE
	target.transform = initial(target.transform)
	return TRUE

/datum/toolgun_mode/resize_mode/ui_data(mob/user)
	. = ..()
	.["scale_value"] = scale_value

/datum/toolgun_mode/resize_mode/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	switch(action)
		if("set_scale")
			var/new_scale = text2num(params["scale"])
			if(!isnum(new_scale))
				return TRUE
			scale_value = clamp(new_scale, 0.2, 5)
			return TRUE
	return ..()


/datum/toolgun_mode/build_mode
	name = "Build mode"
	desc = "Brush, fill and wand terrain construction."
	mode_key = "build"

	var/selected_turf_path = "/turf"
	var/selected_turf = /turf/open/floor/plating
	var/current_search = ""
	var/loaded_limit = 80
	var/page_size = 80
	var/use_custom_color = FALSE
	var/custom_color = "#FFFFFF"
	var/custom_density = FALSE
	var/custom_opacity = FALSE
	var/custom_indestructible = FALSE
	var/build_action = "brush"
	var/wand_range = 3
	var/max_fill_tiles = 600
	var/static/list/cached_turf_type_nodes
	var/static/list/cached_turf_entries

/datum/toolgun_mode/build_mode/main_act(atom/target, mob/user)
	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return FALSE

	switch(build_action)
		if("fill")
			return fill_region(target_turf)
		if("wand")
			return wand_replace(target_turf)
		else
			return apply_to_turf(target_turf)

/datum/toolgun_mode/build_mode/secondnary_act(atom/target, mob/user)
	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return FALSE
	selected_turf = target_turf.type
	selected_turf_path = "[target_turf.type]"
	return TRUE

/datum/toolgun_mode/build_mode/ui_static_data(mob/user)
	build_turf_cache()
	return list(
		"type_nodes" = cached_turf_type_nodes,
	)

/datum/toolgun_mode/build_mode/ui_data(mob/user)
	. = ..()
	.["selected_turf"] = selected_turf_path
	.["search"] = current_search
	.["build_action"] = build_action
	.["wand_range"] = wand_range
	.["use_custom_color"] = use_custom_color
	.["custom_color"] = custom_color
	.["custom_density"] = custom_density
	.["custom_opacity"] = custom_opacity
	.["custom_indestructible"] = custom_indestructible

	build_turf_cache()
	var/list/visible_entries = list()
	var/match_count = 0
	var/filter_by_search = length(current_search) > 0
	var/normalized_search = lowertext(current_search)

	for(var/list/turf_entry as anything in cached_turf_entries)
		var/turf_type = turf_entry["type"]
		if(selected_turf_path != "/turf" && copytext(turf_type, 1, length(selected_turf_path) + 1) != selected_turf_path)
			continue
		if(filter_by_search)
			var/turf_name = lowertext("[turf_entry["name"]]")
			var/lower_type = lowertext(turf_type)
			if(!findtext(turf_name, normalized_search) && !findtext(lower_type, normalized_search))
				continue
		match_count++
		if(filter_by_search || match_count <= loaded_limit)
			visible_entries += list(turf_entry)

	.["turfs"] = visible_entries
	.["visible_count"] = length(visible_entries)
	.["match_count"] = match_count
	.["has_more"] = !filter_by_search && match_count > loaded_limit

/datum/toolgun_mode/build_mode/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	switch(action)
		if("select_turf")
			var/path_to_select = params["path"]
			var/type_to_select = text2path(path_to_select)
			if(type_to_select && ispath(type_to_select, /turf))
				selected_turf_path = path_to_select
				selected_turf = type_to_select
				loaded_limit = page_size
			return TRUE
		if("set_search")
			current_search = trimtext(params["search"])
			loaded_limit = page_size
			return TRUE
		if("load_more")
			if(!length(current_search))
				loaded_limit += page_size
			return TRUE
		if("set_build_action")
			var/new_action = trimtext(params["build_action"])
			if(new_action in list("brush", "fill", "wand"))
				build_action = new_action
			return TRUE
		if("set_wand_range")
			var/new_range = text2num(params["range"])
			if(isnum(new_range))
				wand_range = clamp(new_range, 1, 12)
			return TRUE
		if("set_custom_color")
			var/new_color = trimtext(params["color"])
			if(length(new_color))
				custom_color = new_color
			return TRUE
		if("pick_custom_color")
			var/chosen_color = tgui_color_picker(usr, "Select build color", "Toolgun build mode", custom_color)
			if(chosen_color)
				custom_color = chosen_color
			return TRUE
		if("toggle_use_custom_color")
			use_custom_color = !use_custom_color
			return TRUE
		if("toggle_custom_density")
			custom_density = !custom_density
			return TRUE
		if("toggle_custom_opacity")
			custom_opacity = !custom_opacity
			return TRUE
		if("toggle_custom_indestructible")
			custom_indestructible = !custom_indestructible
			return TRUE
		if("build_here")
			return main_act(get_turf(usr), usr)
	return ..()

/datum/toolgun_mode/build_mode/proc/build_turf_cache()
	if(cached_turf_type_nodes && cached_turf_entries)
		return

	cached_turf_type_nodes = list()
	cached_turf_entries = list()
	for(var/turf/turf_path as anything in subtypesof(/turf))
		var/path_text = "[turf_path]"
		if(!length(path_text))
			continue

		var/list/path_parts = splittext(path_text, "/")
		var/current_path = ""
		var/parent_path = ""
		for(var/path_part in path_parts)
			if(!length(path_part))
				continue
			current_path += "/[path_part]"
			if(!cached_turf_type_nodes[current_path])
				cached_turf_type_nodes[current_path] = list(
					"id" = current_path,
					"parent" = parent_path,
					"name" = path_part,
				)
			parent_path = current_path

		cached_turf_entries += list(list(
			"type" = path_text,
			"name" = initial(turf_path.name),
			"icon" = "[initial(turf_path.icon)]",
			"icon_state" = "[initial(turf_path.icon_state)]",
		))

/datum/toolgun_mode/build_mode/proc/apply_to_turf(turf/target_turf)
	if(!target_turf || !selected_turf || !ispath(selected_turf, /turf))
		return FALSE
	var/turf/new_turf = target_turf
	if(target_turf.type != selected_turf)
		new_turf = target_turf.ChangeTurf(selected_turf, flags = CHANGETURF_INHERIT_AIR)
	if(!new_turf)
		return FALSE
	if(use_custom_color)
		new_turf.color = custom_color
	new_turf.density = custom_density
	new_turf.opacity = custom_opacity
	set_indestructible(new_turf, custom_indestructible)
	return TRUE

/datum/toolgun_mode/build_mode/proc/wand_replace(turf/center_turf)
	if(!center_turf)
		return FALSE
	var/changed_tiles = 0
	for(var/turf/T in range(wand_range, center_turf))
		if(apply_to_turf(T))
			changed_tiles++
	return changed_tiles > 0

/datum/toolgun_mode/build_mode/proc/fill_region(turf/start_turf)
	if(!start_turf || !selected_turf)
		return FALSE
	var/start_type = start_turf.type
	var/list/pending = list(start_turf)
	var/list/visited = list("\ref[start_turf]" = TRUE)
	var/processed = 0

	while(length(pending) && processed < max_fill_tiles)
		var/turf/current = pending[1]
		pending.Cut(1, 2)
		if(!current || current.type != start_type)
			continue
		if(!apply_to_turf(current))
			continue
		processed++

		for(var/direction in GLOB.cardinals)
			var/turf/neighbor = get_step(current, direction)
			if(!neighbor || neighbor.type != start_type)
				continue
			var/neighbor_key = "\ref[neighbor]"
			if(visited[neighbor_key])
				continue
			visited[neighbor_key] = TRUE
			pending += neighbor

	return processed > 0

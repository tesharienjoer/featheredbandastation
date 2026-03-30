/obj/item/toolgun
	name = "Toolgun"
	desc = "Some kind of a revolver with a bluespace power cell and an anomaly core attached together."
	icon = 'modular_bandastation/fenysha_events/icons/items/tools/gmod_tools.dmi'
	icon_state = "toolgun"
	inhand_icon_state = "toolgun"
	lefthand_file = 'modular_bandastation/fenysha_events/icons/items/inhand/tools/gmod_tools_left.dmi'
	righthand_file = 'modular_bandastation/fenysha_events/icons/items/inhand/tools/gmod_tools_right.dmi'
	demolition_mod = 0.5
	w_class = WEIGHT_CLASS_SMALL
	throwforce = 0
	throw_speed = 1
	throw_range = 1
	drop_sound = 'sound/items/handling/tools/screwdriver_drop.ogg'
	pickup_sound = 'modular_bandastation/fenysha_events/sounds/tools/phystools/toolgun_select.ogg'
	resistance_flags = INDESTRUCTIBLE


	/// The mode that is chosen at the moment
	var/datum/toolgun_mode/selected_mode
	/// Available modes
	var/list/datum/toolgun_mode/available_modes = list(
		/datum/toolgun_mode/spawn_mode,
		/datum/toolgun_mode/color_mode,
		/datum/toolgun_mode/resize_mode,
	)
	/// The datum of the beam
	var/datum/beam/work_beam

/obj/item/toolgun/examine(mob/user)
	. = ..()
	. += span_notice("Use ALT + LMB on the device to choose the mode.")
	if(!selected_mode)
		. += span_notice("No selected mode!")
		return
	. += span_notice(selected_mode.desc)

/obj/item/toolgun/click_alt(mob/user)
	. = ..()
	if(selected_mode)
		qdel(selected_mode)
	var/datum/toolgun_mode/mode_to_select = tgui_input_list(user, "Select work mode:", "toolgun mode", available_modes)
	if(!mode_to_select)
		return
	selected_mode = new mode_to_select
	selected_mode.our_tool = src
	selected_mode.on_selected(user)
	playsound(user, 'modular_bandastation/fenysha_events/sounds/tools/phystools/toolgun_select.ogg', 100, TRUE)

/obj/item/toolgun/attack_self(mob/user)
	. = ..()
	if(!selected_mode)
		return
	selected_mode.use_act(user)

/obj/item/toolgun/ui_state(mob/user)
	return GLOB.hands_state

/obj/item/toolgun/ui_interact(mob/user, datum/tgui/ui)
	if(!selected_mode)
		balloon_alert(user, "mode is not selected")
		return
	selected_mode.ui_interact(user, ui)

/obj/item/toolgun/ui_static_data(mob/user)
	if(!selected_mode)
		return list()
	return selected_mode.ui_static_data(user)

/obj/item/toolgun/ui_data(mob/user)
	if(!selected_mode)
		return list()
	return selected_mode.ui_data(user)

/obj/item/toolgun/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!selected_mode)
		return TRUE
	return selected_mode.ui_act(action, params, ui, state)

/obj/item/toolgun/ranged_interact_with_atom(atom/target, mob/user, list/modifiers)
	. = ..()
	if(!selected_mode)
		return
	if(!selected_mode.main_act(target, user))
		playsound(user, 'modular_bandastation/fenysha_events/sounds/tools/phystools/toolgun_error.ogg', 100, TRUE)
		return
	do_work_effect(target, user)
	playsound(user, 'modular_bandastation/fenysha_events/sounds/tools/phystools/toolgun_shot1.ogg', 100, TRUE)

/obj/item/toolgun/ranged_interact_with_atom_secondary(atom/target, mob/user, proximity_flag, list/modifiers)
	. = ..()
	if(!selected_mode)
		return
	if(!selected_mode.secondnary_act(target, user))
		playsound(user, 'modular_bandastation/fenysha_events/sounds/tools/phystools/toolgun_error.ogg', 100, TRUE)
		return
	do_work_effect(target, user)
	playsound(user, 'modular_bandastation/fenysha_events/sounds/tools/phystools/toolgun_shot1.ogg', 100, TRUE)

/obj/item/toolgun/proc/do_work_effect(atom/target, mob/user)
	if(!target)
		return
	work_beam = user.Beam(target, "light_beam", time = 3)

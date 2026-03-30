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
		ui = new(user, src, tgui_ui_id, name)
		ui.open()

/datum/toolgun_mode/ui_static_data(mob/user)
	return list()

/datum/toolgun_mode/ui_data(mob/user)
	return list(
		"mode_name" = name,
		"mode_desc" = desc,
		"mode_key" = mode_key,
	)


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
	new selected_type(target_turf)
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

	build_spawn_cache()
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

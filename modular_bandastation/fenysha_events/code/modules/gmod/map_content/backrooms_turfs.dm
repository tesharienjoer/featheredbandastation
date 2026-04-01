/turf/closed/indestructible/backrooms
	icon = 'modular_bandastation/fenysha_events/icons/turf/backrooms_wall.dmi'
	base_icon_state = "backrooms_wall"
	icon_state = "backrooms_wall-0"
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_WALLS_SHINNY
	canSmoothWith = SMOOTH_GROUP_WALLS_SHINNY

	baseturfs = /turf/open/indestructible/backrooms

/turf/closed/indestructible/CanPass(atom/movable/mover, border_dir)
	SHOULD_CALL_PARENT(FALSE)
	return FALSE

/turf/open/indestructible/backrooms
	name = "Carpet"
	icon = 'modular_bandastation/fenysha_events/icons/turf/floors/floors.dmi'
	icon_state = "backrooms_carpet"

	baseturfs = /turf/open/indestructible/backrooms

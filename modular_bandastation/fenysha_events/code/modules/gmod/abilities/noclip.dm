/datum/action/cooldown/noclip
	name = "Переключить noclip"
	desc = "При активации позволяет двигаться сквозь твердые обьекты!"
	cooldown_time = 1 SECONDS

	button_icon = 'icons/effects/effects.dmi'
	button_icon_state = "blank_white"

	var/enabled = FALSE
	var/initial_pass_flags = NONE

/datum/action/cooldown/noclip/IsAvailable(feedback)
	if(owner.stat & DEAD)
		return FALSE
	if(INCAPACITATED_IGNORING(owner, INCAPABLE_GRAB))
		return FALSE
	return ..()

/datum/action/cooldown/noclip/Activate(atom/target)
	. = ..()
	if(enabled)
		disable_noclip()
		return TRUE
	enable_noclip()
	return TRUE

/datum/action/cooldown/noclip/proc/enable_noclip()
	initial_pass_flags = owner.pass_flags
	owner.pass_flags = PASSCLOSEDTURF | PASSTABLE | PASSDOORS | PASSBLOB | PASSGLASS | PASSGRILLE | PASSMOB | PASSSTRUCTURE | PASSVEHICLE | PASSWINDOW | PASSITEM

	owner.add_movespeed_modifier(/datum/movespeed_modifier/noclip)
	owner.visible_message(span_notice("[owner.name], dissolves in air. Becoming non-physical."), span_notice("You going noclip."))

	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(owner_dead), TRUE)

	button_icon_state = "blank"
	enabled = TRUE
	build_all_button_icons(UPDATE_BUTTON_ICON)

/datum/action/cooldown/noclip/proc/disable_noclip()
	owner.pass_flags = initial_pass_flags

	owner.remove_movespeed_modifier(/datum/movespeed_modifier/noclip)
	owner.visible_message(span_notice("[owner.name], becomes physical again."), span_notice("You back to normal again."))
	UnregisterSignal(owner, COMSIG_LIVING_DEATH)

	enabled = FALSE
	button_icon_state = "blank_white"
	build_all_button_icons(UPDATE_BUTTON_ICON)

/datum/action/cooldown/noclip/proc/owner_dead()
	SIGNAL_HANDLER

	if(enabled)
		disable_noclip()
		StartCooldown()

/datum/movespeed_modifier/noclip
	id = "noclip"
	movetypes = GROUND | FLYING
	multiplicative_slowdown = -0.4

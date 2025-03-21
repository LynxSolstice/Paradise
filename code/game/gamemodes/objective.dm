GLOBAL_LIST_EMPTY(all_objectives)

GLOBAL_LIST_INIT(potential_theft_objectives, (subtypesof(/datum/theft_objective) - /datum/theft_objective/steal - /datum/theft_objective/number - /datum/theft_objective/unique))

/datum/objective
	/// Mind who owns the objective.
	var/datum/mind/owner = null
	/// What the owner is supposed to do to complete the objective.
	var/explanation_text = "Nothing"
	/// If the objective should have `find_target()` called for it.
	var/needs_target = TRUE
	/// The target of the objective.
	var/datum/mind/target = null
	/// If they are focused on a particular number. Steal objectives have their own counter.
	var/target_amount = 0
	/// If the objective has been completed.
	var/completed = FALSE
	/// If the objective is compatible with martyr objective, i.e. if you can still do it while dead.
	var/martyr_compatible = FALSE

/datum/objective/New(text)
	GLOB.all_objectives += src
	if(text)
		explanation_text = text

/datum/objective/Destroy()
	GLOB.all_objectives -= src
	return ..()

/datum/objective/proc/check_completion()
	return completed

/datum/proc/is_invalid_target(datum/mind/possible_target) // Originally an Objective proc. Changed to a datum proc to allow for the proc to be run on minds, before the objective is created
	if(!ishuman(possible_target.current))
		return TARGET_INVALID_NOT_HUMAN
	if(possible_target.current.stat == DEAD)
		return TARGET_INVALID_DEAD
	if(!possible_target.key)
		return TARGET_INVALID_NOCKEY
	if(possible_target.current)
		var/turf/current_location = get_turf(possible_target.current)
		if(current_location && !is_level_reachable(current_location.z))
			return TARGET_INVALID_UNREACHABLE
	if(isgolem(possible_target.current))
		return TARGET_INVALID_GOLEM
	if(possible_target.offstation_role)
		return TARGET_INVALID_EVENT

/datum/objective/is_invalid_target(datum/mind/possible_target)
	if(possible_target == owner)
		return TARGET_INVALID_IS_OWNER
	if(possible_target in owner.targets)
		return TARGET_INVALID_IS_TARGET
	return ..()


/datum/objective/proc/find_target()
	if(!needs_target)
		return

	var/list/possible_targets = list()
	for(var/datum/mind/possible_target in SSticker.minds)
		if(is_invalid_target(possible_target))
			continue

		possible_targets += possible_target

	if(possible_targets.len > 0)
		target = pick(possible_targets)

/**
  * Called when the objective's target goes to cryo.
  */
/datum/objective/proc/on_target_cryo()
	if(owner?.current)
		to_chat(owner.current, "<BR><span class='userdanger'>You get the feeling your target is no longer within reach. Time for Plan [pick("A","B","C","D","X","Y","Z")]. Objectives updated!</span>")
		SEND_SOUND(owner.current, sound('sound/ambience/alarm4.ogg'))
	target = null
	INVOKE_ASYNC(src, PROC_REF(post_target_cryo))

/**
  * Called a tick after when the objective's target goes to cryo.
  */
/datum/objective/proc/post_target_cryo()
	find_target()
	if(!target)
		GLOB.all_objectives -= src
		owner?.objectives -= src
		qdel(src)
	owner?.announce_objectives()

/datum/objective/assassinate
	martyr_compatible = 1

/datum/objective/assassinate/find_target()
	..()
	if(target && target.current)
		explanation_text = "Assassinate [target.current.real_name], the [target.assigned_role]."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/assassinate/check_completion()
	if(target && target.current)
		if(target.current.stat == DEAD)
			return 1
		if(issilicon(target.current) || isbrain(target.current)) //Borgs/brains/AIs count as dead for traitor objectives. --NeoFite
			return 1
		if(!target.current.ckey)
			return 1
		return 0
	return 1


/datum/objective/mutiny
	martyr_compatible = 1

/datum/objective/mutiny/find_target()
	..()
	if(target && target.current)
		explanation_text = "Assassinate [target.current.real_name], the [target.assigned_role]."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/mutiny/check_completion()
	if(target && target.current)
		if(target.current.stat == DEAD || !ishuman(target.current) || !target.current.ckey || !target.current.client)
			return 1
		var/turf/T = get_turf(target.current)
		if(T && !is_station_level(T.z))			//If they leave the station they count as dead for this
			return 1
		return 0
	return 1

/datum/objective/mutiny/on_target_cryo()
	// We don't want revs to get objectives that aren't for heads of staff. Letting
	// them win or lose based on cryo is silly so we remove the objective.
	qdel(src)

/datum/objective/maroon
	martyr_compatible = 1

/datum/objective/maroon/find_target()
	..()
	if(target && target.current)
		explanation_text = "Prevent [target.current.real_name], the [target.assigned_role] from escaping alive."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/maroon/check_completion()
	if(target && target.current)
		if(target.current.stat == DEAD)
			return 1
		if(!target.current.ckey)
			return 1
		if(issilicon(target.current))
			return 1
		if(isbrain(target.current))
			return 1
		var/turf/T = get_turf(target.current)
		if(is_admin_level(T.z))
			return 0
		return 1
	return 1


/datum/objective/debrain //I want braaaainssss
	martyr_compatible = 0

/datum/objective/debrain/find_target()
	..()
	if(target && target.current)
		explanation_text = "Steal the brain of [target.current.real_name] the [target.assigned_role]."
	else
		explanation_text = "Free Objective"
	return target


/datum/objective/debrain/check_completion()
	if(!target)//If it's a free objective.
		return 1
	if(!owner.current || owner.current.stat == DEAD)
		return 0
	if(!target.current || !isbrain(target.current))
		return 0
	var/atom/A = target.current
	while(A.loc)			//check to see if the brainmob is on our person
		A = A.loc
		if(A == owner.current)
			return 1
	return 0


/datum/objective/protect //The opposite of killing a dude.
	martyr_compatible = 1

/datum/objective/protect/find_target()
	..()
	if(target && target.current)
		explanation_text = "Protect [target.current.real_name], the [target.assigned_role]."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/protect/check_completion()
	if(!target) //If it's a free objective.
		return 1
	if(target.current)
		if(target.current.stat == DEAD)
			return 0
		if(issilicon(target.current))
			return 0
		if(isbrain(target.current))
			return 0
		return 1
	return 0

/datum/objective/protect/mindslave //subytpe for mindslave implants
	needs_target = FALSE // To be clear, this objective should have a target, but it will always be manually set to the mindslaver through the mindslave antag datum.

/datum/objective/protect/mindslave/on_target_cryo()
	if(owner?.current)
		SEND_SOUND(owner.current, sound('sound/ambience/alarm4.ogg'))
		owner.remove_antag_datum(/datum/antagonist/mindslave)
		to_chat(owner.current, "<BR><span class='userdanger'>You notice that your master has entered cryogenic storage, and revert to your normal self.</span>")
		log_admin("[key_name(owner.current)]'s mindslave master has cryo'd, and is no longer a mindslave.")
		message_admins("[key_name_admin(owner.current)]'s mindslave master has cryo'd, and is no longer a mindslave.") //Since they were on antag hud earlier, this feels important to log
		qdel(src)

/datum/objective/hijack
	martyr_compatible = 0 //Technically you won't get both anyway.
	explanation_text = "Hijack the shuttle by escaping on it with no loyalist Nanotrasen crew on board and free. \
	Syndicate agents, other enemies of Nanotrasen, cyborgs, pets, and cuffed/restrained hostages may be allowed on the shuttle alive. \
	Alternatively, hack the shuttle console multiple times (by alt clicking on it) until the shuttle directions are corrupted."
	needs_target = FALSE

/datum/objective/hijack/check_completion()
	if(!owner.current || owner.current.stat)
		return 0
	if(SSshuttle.emergency.mode < SHUTTLE_ENDGAME)
		return 0
	if(issilicon(owner.current))
		return 0

	var/area/A = get_area(owner.current)
	if(SSshuttle.emergency.areaInstance != A)
		return 0

	return SSshuttle.emergency.is_hijacked()

/datum/objective/hijackclone
	explanation_text = "Hijack the shuttle by ensuring only you (or your copies) escape."
	martyr_compatible = 0
	needs_target = FALSE

/datum/objective/hijackclone/check_completion()
	if(!owner.current)
		return 0
	if(SSshuttle.emergency.mode < SHUTTLE_ENDGAME)
		return 0

	var/area/A = SSshuttle.emergency.areaInstance

	for(var/mob/living/player in GLOB.player_list) //Make sure nobody else is onboard
		if(player.mind && player.mind != owner)
			if(player.stat != DEAD)
				if(issilicon(player))
					continue
				if(get_area(player) == A)
					if(player.real_name != owner.current.real_name && !istype(get_turf(player.mind.current), /turf/simulated/floor/mineral/plastitanium/red/brig))
						return 0

	for(var/mob/living/player in GLOB.player_list) //Make sure at least one of you is onboard
		if(player.mind && player.mind != owner)
			if(player.stat != DEAD)
				if(issilicon(player))
					continue
				if(get_area(player) == A)
					if(player.real_name == owner.current.real_name && !istype(get_turf(player.mind.current), /turf/simulated/floor/mineral/plastitanium/red/brig))
						return 1
	return 0

/datum/objective/block
	explanation_text = "Hijack the shuttle with no loyalist Nanotrasen crew on board and free. \
	Syndicate agents, other enemies of Nanotrasen, cyborgs, pets, and cuffed/restrained hostages may be allowed on the shuttle alive. \
	Using the doomsday device successfully is also an option."
	martyr_compatible = 1
	needs_target = FALSE

/datum/objective/block/check_completion()
	if(!issilicon(owner.current))
		return FALSE
	if(SSticker.mode.station_was_nuked)
		return TRUE
	if(SSshuttle.emergency.mode < SHUTTLE_ENDGAME)
		return FALSE
	if(!owner.current)
		return FALSE
	if(!SSshuttle.emergency.is_hijacked(TRUE))
		return FALSE

	return TRUE

/datum/objective/escape
	explanation_text = "Escape on the shuttle or an escape pod alive and free."
	needs_target = FALSE

/datum/objective/escape/check_completion()
	if(issilicon(owner.current))
		return 0
	if(isbrain(owner.current))
		return 0
	if(!owner.current || owner.current.stat == DEAD)
		return 0
	if(SSticker.force_ending) //This one isn't their fault, so lets just assume good faith
		return 1
	if(SSticker.mode.station_was_nuked) //If they escaped the blast somehow, let them win
		return 1
	if(SSshuttle.emergency.mode < SHUTTLE_ENDGAME)
		return 0
	var/turf/location = get_turf(owner.current)
	if(!location)
		return 0

	if(istype(location, /turf/simulated/floor/mineral/plastitanium/red/brig)) // Fails traitors if they are in the shuttle brig -- Polymorph
		return 0

	if(location.onCentcom() || location.onSyndieBase())
		return 1

	return 0


/datum/objective/escape/escape_with_identity
	var/target_real_name // Has to be stored because the target's real_name can change over the course of the round

/datum/objective/escape/escape_with_identity/find_target()
	var/list/possible_targets = list() //Copypasta because NO_DNA races, yay for snowflakes.
	for(var/datum/mind/possible_target in SSticker.minds)
		if(possible_target != owner && ishuman(possible_target.current) && (possible_target.current.stat != DEAD) && possible_target.current.client)
			var/mob/living/carbon/human/H = possible_target.current
			if(!HAS_TRAIT(H, TRAIT_GENELESS))
				possible_targets += possible_target
	if(possible_targets.len > 0)
		target = pick(possible_targets)
	if(target && target.current)
		target_real_name = target.current.real_name
		explanation_text = "Escape on the shuttle or an escape pod with the identity of [target_real_name], the [target.assigned_role] while wearing [target.p_their()] identification card."
	else
		explanation_text = "Free Objective"

/datum/objective/escape/escape_with_identity/check_completion()
	if(!target_real_name)
		return 1
	if(!ishuman(owner.current))
		return 0
	var/mob/living/carbon/human/H = owner.current
	if(..())
		if(H.dna.real_name == target_real_name)
			if(H.get_id_name()== target_real_name)
				return 1
	return 0

/datum/objective/die
	explanation_text = "Die a glorious death."
	needs_target = FALSE

/datum/objective/die/check_completion()
	if(!owner.current || owner.current.stat == DEAD || isbrain(owner.current))
		return 1
	if(issilicon(owner.current) && !owner.is_original_mob(owner.current))
		return 1
	return 0



/datum/objective/survive
	explanation_text = "Stay alive until the end."
	needs_target = FALSE

/datum/objective/survive/check_completion()
	if(!owner.current || owner.current.stat == DEAD || isbrain(owner.current))
		return 0		//Brains no longer win survive objectives. --NEO
	if(issilicon(owner.current) && !owner.is_original_mob(owner.current))
		return 0
	return 1

/datum/objective/nuclear
	explanation_text = "Destroy the station with a nuclear device."
	martyr_compatible = 1
	needs_target = FALSE

/datum/objective/steal
	var/datum/theft_objective/steal_target
	martyr_compatible = 0
	var/theft_area

/datum/objective/steal/proc/get_location()
	return steal_target.location_override || "an unknown area"

/datum/objective/steal/find_target()
	var/potential = GLOB.potential_theft_objectives.Copy()
	while(!steal_target && length(potential))
		var/thefttype = pick_n_take(potential)
		var/datum/theft_objective/O = new thefttype
		if(owner.assigned_role in O.protected_jobs)
			continue
		if(O in owner.targets)
			continue
		if(O.flags & 2) // THEFT_FLAG_UNIQUE
			continue

		steal_target = O
		explanation_text = "Steal [steal_target]. One was last seen in [get_location()]. "
		if(length(O.protected_jobs) && O.job_possession)
			explanation_text += "It may also be in the possession of the [english_list(O.protected_jobs, and_text = " or ")]."
		if(steal_target.special_equipment)
			give_kit(steal_target.special_equipment)
		return
	explanation_text = "Free Objective."

/datum/objective/steal/proc/select_target()
	var/list/possible_items_all = GLOB.potential_theft_objectives+"custom"
	var/new_target = input("Select target:", "Objective target", null) as null|anything in possible_items_all
	if(!new_target) return
	if(new_target == "custom")
		var/datum/theft_objective/O=new
		O.typepath = input("Select type:","Type") as null|anything in typesof(/obj/item)
		if(!O.typepath) return
		var/tmp_obj = new O.typepath
		var/custom_name = tmp_obj:name
		qdel(tmp_obj)
		O.name = sanitize(copytext(input("Enter target name:", "Objective target", custom_name) as text|null,1,MAX_NAME_LEN))
		if(!O.name) return
		steal_target = O
		explanation_text = "Steal [O.name]."
	else
		steal_target = new new_target
		explanation_text = "Steal [steal_target.name]."
		if(steal_target.special_equipment)
			give_kit(steal_target.special_equipment)
	return steal_target

/datum/objective/steal/check_completion()
	if(!steal_target)
		return 1 // Free Objective

	if(!owner.current)
		return FALSE

	var/list/all_items = owner.current.GetAllContents()

	for(var/obj/I in all_items)
		if(istype(I, steal_target.typepath))
			return steal_target.check_special_completion(I)
		if(I.type in steal_target.altitems)
			return steal_target.check_special_completion(I)

/datum/objective/steal/proc/give_kit(obj/item/item_path)
	var/mob/living/carbon/human/mob = owner.current
	var/I = new item_path
	var/list/slots = list(
		"backpack" = slot_in_backpack,
		"left pocket" = slot_l_store,
		"right pocket" = slot_r_store,
		"left hand" = slot_l_hand,
		"right hand" = slot_r_hand,
	)
	var/where = mob.equip_in_one_of_slots(I, slots)
	if(where)
		to_chat(mob, "<br><br><span class='info'>In your [where] is a box containing <b>items and instructions</b> to help you with your steal objective.</span><br>")
	else
		to_chat(mob, "<span class='userdanger'>Unfortunately, you weren't able to get a stealing kit. This is very bad and you should adminhelp immediately (press F1).</span>")
		message_admins("[ADMIN_LOOKUPFLW(mob)] Failed to spawn with their [item_path] theft kit.")
		qdel(I)

/datum/objective/steal/exchange
	martyr_compatible = 0
	needs_target = FALSE

/datum/objective/steal/exchange/proc/set_faction(faction, otheragent)
	target = otheragent
	var/datum/theft_objective/unique/targetinfo
	if(faction == "red")
		targetinfo = new /datum/theft_objective/unique/docs_blue
	else if(faction == "blue")
		targetinfo = new /datum/theft_objective/unique/docs_red
	explanation_text = "Acquire [targetinfo.name] held by [target.current.real_name], the [target.assigned_role] and syndicate agent"
	steal_target = targetinfo

/datum/objective/steal/exchange/backstab
/datum/objective/steal/exchange/backstab/set_faction(faction)
	var/datum/theft_objective/unique/targetinfo
	if(faction == "red")
		targetinfo = new /datum/theft_objective/unique/docs_red
	else if(faction == "blue")
		targetinfo = new /datum/theft_objective/unique/docs_blue
	explanation_text = "Do not give up or lose [targetinfo.name]."
	steal_target = targetinfo

/datum/objective/download
	needs_target = FALSE

/datum/objective/download/proc/gen_amount_goal()
	target_amount = rand(10,20)
	explanation_text = "Download [target_amount] research levels."
	return target_amount


/datum/objective/download/check_completion()
	return 0



/datum/objective/capture
	needs_target = FALSE

/datum/objective/capture/proc/gen_amount_goal()
	target_amount = rand(5,10)
	explanation_text = "Accumulate [target_amount] capture points."
	return target_amount


/datum/objective/capture/check_completion()//Basically runs through all the mobs in the area to determine how much they are worth.
	return 0




/datum/objective/absorb
	needs_target = FALSE

/datum/objective/absorb/proc/gen_amount_goal(lowbound = 4, highbound = 6)
	target_amount = rand (lowbound,highbound)
	if(SSticker)
		var/n_p = 1 //autowin
		if(SSticker.current_state == GAME_STATE_SETTING_UP)
			for(var/mob/new_player/P in GLOB.player_list)
				if(P.client && P.ready && P.mind != owner)
					if(P.client.prefs && (P.client.prefs.active_character.species == "Machine")) // Special check for species that can't be absorbed. No better solution.
						continue
					n_p++
		else if(SSticker.current_state == GAME_STATE_PLAYING)
			for(var/mob/living/carbon/human/P in GLOB.player_list)
				if(HAS_TRAIT(P, TRAIT_GENELESS))
					continue
				if(P.client && !(P.mind in SSticker.mode.changelings) && P.mind!=owner)
					n_p++
		target_amount = min(target_amount, n_p)

	explanation_text = "Acquire [target_amount] compatible genomes. The 'Extract DNA Sting' can be used to stealthily get genomes without killing somebody."
	return target_amount

/datum/objective/absorb/check_completion()
	var/datum/antagonist/changeling/cling = owner?.has_antag_datum(/datum/antagonist/changeling)
	if(cling?.absorbed_dna && (cling.absorbed_count >= target_amount))
		return TRUE
	return FALSE

/datum/objective/destroy
	martyr_compatible = 1
	var/target_real_name

/datum/objective/destroy/find_target()
	var/list/possible_targets = active_ais(1)
	var/mob/living/silicon/ai/target_ai = pick(possible_targets)
	target = target_ai.mind
	if(target && target.current)
		target_real_name = target.current.real_name
		explanation_text = "Destroy [target_real_name], the AI."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/destroy/check_completion()
	if(target && target.current)
		if(target.current.stat == DEAD || is_away_level(target.current.z) || !target.current.ckey)
			return 1
		return 0
	return 1

/datum/objective/steal_five_of_type
	explanation_text = "Steal at least five items!"
	needs_target = FALSE
	var/list/wanted_items = list()

/datum/objective/steal_five_of_type/New()
	..()
	wanted_items = typecacheof(wanted_items)

/datum/objective/steal_five_of_type/check_completion()
	var/stolen_count = 0
	if(!isliving(owner.current))
		return FALSE
	var/list/all_items = owner.current.GetAllContents()	//this should get things in cheesewheels, books, etc.
	for(var/obj/I in all_items) //Check for wanted items
		if(is_type_in_typecache(I, wanted_items))
			stolen_count++
	return stolen_count >= 5

/datum/objective/steal_five_of_type/summon_guns
	explanation_text = "Steal at least five guns!"
	wanted_items = list(/obj/item/gun)

/datum/objective/steal_five_of_type/summon_magic
	explanation_text = "Steal at least five magical artefacts!"
	wanted_items = list()

/datum/objective/steal_five_of_type/summon_magic/New()
	wanted_items = GLOB.summoned_magic_objectives
	..()

/datum/objective/steal_five_of_type/summon_magic/check_completion()
	var/stolen_count = 0
	if(!isliving(owner.current))
		return FALSE
	var/list/all_items = owner.current.GetAllContents()	//this should get things in cheesewheels, books, etc.
	for(var/obj/I in all_items) //Check for wanted items
		if(istype(I, /obj/item/spellbook) && !istype(I, /obj/item/spellbook/oneuse))
			var/obj/item/spellbook/spellbook = I
			if(spellbook.uses) //if the book still has powers...
				stolen_count++ //it counts. nice.
		if(istype(I, /obj/item/spellbook/oneuse))
			var/obj/item/spellbook/oneuse/oneuse = I
			if(!oneuse.used)
				stolen_count++
		else if(is_type_in_typecache(I, wanted_items))
			stolen_count++
	return stolen_count >= 5

/datum/objective/blood
	needs_target = FALSE

/datum/objective/blood/New()
	gen_amount_goal()
	. = ..()

/datum/objective/blood/proc/gen_amount_goal(low = 150, high = 400)
	target_amount = rand(low,high)
	target_amount = round(round(target_amount/5)*5)
	explanation_text = "Accumulate at least [target_amount] total units of blood."
	return target_amount

/datum/objective/blood/check_completion()
	var/datum/antagonist/vampire/V = owner.has_antag_datum(/datum/antagonist/vampire)
	if(V.bloodtotal >= target_amount)
		return TRUE
	else
		return FALSE


// Traders
// These objectives have no check_completion, they exist only to tell Sol Traders what to aim for.

/datum/objective/trade/proc/choose_target()
	return

/datum/objective/trade/plasma/choose_target()
	explanation_text = "Acquire at least 15 sheets of plasma through trade."

/datum/objective/trade/credits/choose_target()
	explanation_text = "Acquire at least 10,000 credits through trade."

//wizard

/datum/objective/wizchaos
	explanation_text = "Wreak havoc upon the station as much you can. Send those wandless Nanotrasen scum a message!"
	needs_target = FALSE
	completed = 1

/* Two-handed Weapons
 * Contains:
 * 		Twohanded
 *		Fireaxe
 *		Double-Bladed Energy Swords
 *		Spears
 *		Kidan spear
 *		Chainsaw
 *		Singularity hammer
 *		Mjolnnir
 *		Knighthammer
 *		Pyro Claws
 */

/*##################################################################
##################### TWO HANDED WEAPONS BE HERE~ -Agouri :3 ########
####################################################################*/

//Rewrote TwoHanded weapons stuff and put it all here. Just copypasta fireaxe to make new ones ~Carn
//This rewrite means we don't have two variables for EVERY item which are used only by a few weapons.
//It also tidies stuff up elsewhere.

/*
 * Twohanded
 */
/obj/item/twohanded
	var/wielded = FALSE
	var/force_unwielded = 0
	var/force_wielded = 0
	var/wieldsound = null
	var/unwieldsound = null
	var/sharp_when_wielded = FALSE

/obj/item/twohanded/proc/unwield(mob/living/carbon/user)
	if(!wielded || !user)
		return FALSE
	wielded = FALSE
	force = force_unwielded
	if(sharp_when_wielded)
		set_sharpness(FALSE)
	var/sf = findtext(name," (Wielded)")
	if(sf)
		name = copytext(name, 1, sf)
	else //something wrong
		name = "[initial(name)]"
	update_icon()
	if(user)
		user.update_inv_r_hand()
		user.update_inv_l_hand()
	if(!(flags & ABSTRACT))
		if(isrobot(user))
			to_chat(user, "<span class='notice'>You free up your module.</span>")
		else
			to_chat(user, "<span class='notice'>You are now carrying [name] with one hand.</span>")
	if(unwieldsound)
		playsound(loc, unwieldsound, 50, 1)
	var/obj/item/twohanded/offhand/O = user.get_inactive_hand()
	if(O && istype(O))
		O.unwield()
	return TRUE

/obj/item/twohanded/proc/wield(mob/living/carbon/user)
	if(wielded)
		return FALSE
	if(ishuman(user))
		var/mob/living/carbon/human/H = user
		if(H.dna.species.is_small)
			to_chat(user, "<span class='warning'>It's too heavy for you to wield fully.</span>")
			return FALSE
	if(user.get_inactive_hand())
		to_chat(user, "<span class='warning'>You need your other hand to be empty!</span>")
		return FALSE
	if(!user.has_both_hands())
		to_chat(user, "<span class='warning'>You need both hands to wield this!</span>")
		return FALSE
	wielded = TRUE
	force = force_wielded
	if(sharp_when_wielded)
		set_sharpness(TRUE)
	name = "[name] (Wielded)"
	update_icon()
	if(user)
		user.update_inv_r_hand()
		user.update_inv_l_hand()
	if(!(flags & ABSTRACT))
		if(isrobot(user))
			to_chat(user, "<span class='notice'>You dedicate your module to [src].</span>")
		else
			to_chat(user, "<span class='notice'>You grab [src] with both hands.</span>")
	if(wieldsound)
		playsound(loc, wieldsound, 50, 1)
	var/obj/item/twohanded/offhand/O = new(user) ////Let's reserve his other hand~
	O.name = "[name] - offhand"
	O.desc = "Your second grip on [src]"
	user.put_in_inactive_hand(O)
	return TRUE

/obj/item/twohanded/mob_can_equip(mob/M, slot) //Unwields twohanded items when they're attempted to be equipped to another slot
	if(wielded)
		unwield(M)
	return ..()

/obj/item/twohanded/dropped(mob/user)
	..()
	//handles unwielding a twohanded weapon when dropped as well as clearing up the offhand
	if(user)
		var/obj/item/twohanded/O = user.get_inactive_hand()
		if(istype(O))
			O.unwield(user)
	return unwield(user)

/obj/item/twohanded/attack_self(mob/user)
	..()
	if(wielded) //Trying to unwield it
		unwield(user)
	else //Trying to wield it
		wield(user)


/obj/item/twohanded/equip_to_best_slot(mob/M)
	if(..())
		unwield(M)
		return

///////////OFFHAND///////////////
/obj/item/twohanded/offhand
	w_class = WEIGHT_CLASS_HUGE
	icon_state = "offhand"
	name = "offhand"
	flags = ABSTRACT
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/item/twohanded/offhand/unwield()
	if(!QDELETED(src))
		qdel(src)

/obj/item/twohanded/offhand/wield()
	if(!QDELETED(src))
		qdel(src)

///////////Two hand required objects///////////////
//This is for objects that require two hands to even pick up
/obj/item/twohanded/required
	w_class = WEIGHT_CLASS_HUGE

/obj/item/twohanded/required/attack_self()
	return

/obj/item/twohanded/required/mob_can_equip(mob/M, slot)
	if(wielded && !slot_flags)
		to_chat(M, "<span class='warning'>[src] is too cumbersome to carry with anything but your hands!</span>")
		return FALSE
	return ..()

/obj/item/twohanded/required/attack_hand(mob/user)//Can't even pick it up without both hands empty
	var/obj/item/twohanded/required/H = user.get_inactive_hand()
	if(get_dist(src, user) > 1)
		return FALSE
	if(H != null)
		to_chat(user, "<span class='notice'>[src] is too cumbersome to carry in one hand!</span>")
		return
	if(loc != user)
		wield(user)
	..()

/obj/item/twohanded/required/on_give(mob/living/carbon/giver, mob/living/carbon/receiver)
	var/obj/item/twohanded/required/H = receiver.get_inactive_hand()
	if(H != null) //Check if he can wield it
		receiver.drop_item() //Can't wear it so drop it
		to_chat(receiver, "<span class='notice'>[src] is too cumbersome to carry in one hand!</span>")
		return
	equipped(receiver,receiver.hand ? slot_l_hand : slot_r_hand)

/obj/item/twohanded/required/equipped(mob/user, slot)
	..()
	if(slot == slot_l_hand || slot == slot_r_hand)
		wield(user)
		if(!wielded) // Drop immediately if we couldn't wield
			user.unEquip(src)
			to_chat(user, "<span class='notice'>[src] is too cumbersome to carry in one hand!</span>")
	else
		unwield(user)

/*
 * Fireaxe
 */
/obj/item/twohanded/fireaxe  // DEM AXES MAN, marker -Agouri
	icon_state = "fireaxe0"
	name = "fire axe"
	desc = "Truly, the weapon of a madman. Who would think to fight fire with an axe?"
	force = 5
	throwforce = 15
	sharp = TRUE
	w_class = WEIGHT_CLASS_BULKY
	slot_flags = SLOT_BACK
	force_unwielded = 5
	force_wielded = 24
	toolspeed = 0.25
	attack_verb = list("attacked", "chopped", "cleaved", "torn", "cut")
	hitsound = 'sound/weapons/bladeslice.ogg'
	usesound = 'sound/items/crowbar.ogg'
	max_integrity = 200
	armor = list(MELEE = 0, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 0, BIO = 0, RAD = 0, FIRE = 100, ACID = 30)
	resistance_flags = FIRE_PROOF

/obj/item/twohanded/fireaxe/update_icon_state()  //Currently only here to fuck with the on-mob icons.
	icon_state = "fireaxe[wielded]"

/obj/item/twohanded/fireaxe/afterattack(atom/A, mob/user, proximity)
	if(!proximity)
		return
	if(wielded) //destroys windows and grilles in one hit
		if(istype(A, /obj/structure/window) || istype(A, /obj/structure/grille))
			var/obj/structure/W = A
			W.obj_destruction("fireaxe")

/obj/item/twohanded/fireaxe/boneaxe  // Blatant imitation of the fireaxe, but made out of bone.
	icon_state = "bone_axe0"
	name = "bone axe"
	desc = "A large, vicious axe crafted out of several sharpened bone plates and crudely tied together. Made of monsters, by killing monsters, for killing monsters."
	force_wielded = 23
	needs_permit = TRUE

/obj/item/twohanded/fireaxe/boneaxe/update_icon_state()
	icon_state = "bone_axe[wielded]"

/obj/item/twohanded/fireaxe/energized
	desc = "Someone with a love for fire axes decided to turn this one into a high-powered energy weapon. Seems excessive."
	force_wielded = 35
	armour_penetration_flat = 10
	armour_penetration_percentage = 30
	var/charge = 20
	var/max_charge = 20

/obj/item/twohanded/fireaxe/energized/update_icon_state()
	if(wielded)
		icon_state = "fireaxe2"
	else
		icon_state = "fireaxe0"

/obj/item/twohanded/fireaxe/energized/New()
	..()
	START_PROCESSING(SSobj, src)

/obj/item/twohanded/fireaxe/energized/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/twohanded/fireaxe/energized/process()
	charge = min(charge + 1, max_charge)

/obj/item/twohanded/fireaxe/energized/attack(mob/M, mob/user)
	. = ..()
	if(wielded && charge == max_charge)
		if(isliving(M))
			var/mob/living/target = M
			charge = 0
			playsound(loc, 'sound/magic/lightningbolt.ogg', 5, 1)
			user.visible_message("<span class='danger'>[user] slams the charged axe into [M.name] with all [user.p_their()] might!</span>")
			do_sparks(1, 1, src)
			target.KnockDown(8 SECONDS)
			var/atom/throw_target = get_edge_target_turf(M, get_dir(src, get_step_away(M, src)))
			M.throw_at(throw_target, 5, 1)

/*
 * Double-Bladed Energy Swords - Cheridan
 */
/obj/item/twohanded/dualsaber
	var/hacked = FALSE
	var/blade_color
	icon_state = "dualsaber0"
	name = "double-bladed energy sword"
	desc = "Handle with care."
	force = 3
	throwforce = 5
	throw_speed = 1
	throw_range = 5
	w_class = WEIGHT_CLASS_SMALL
	var/w_class_on = WEIGHT_CLASS_BULKY
	force_unwielded = 3
	force_wielded = 34
	wieldsound = 'sound/weapons/saberon.ogg'
	unwieldsound = 'sound/weapons/saberoff.ogg'
	armour_penetration_percentage = 50
	armour_penetration_flat = 10
	origin_tech = "magnets=4;syndicate=5"
	attack_verb = list("attacked", "slashed", "stabbed", "sliced", "torn", "ripped", "diced", "cut")
	block_chance = 75
	sharp_when_wielded = TRUE // only sharp when wielded
	max_integrity = 200
	armor = list(MELEE = 0, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 0, BIO = 0, RAD = 0, FIRE = 100, ACID = 70)
	resistance_flags = FIRE_PROOF
	light_power = 2
	needs_permit = TRUE
	var/brightness_on = 2
	var/colormap = list(red=LIGHT_COLOR_RED, blue=LIGHT_COLOR_LIGHTBLUE, green=LIGHT_COLOR_GREEN, purple=LIGHT_COLOR_PURPLE, rainbow=LIGHT_COLOR_WHITE)

/obj/item/twohanded/dualsaber/New()
	..()
	if(!blade_color)
		blade_color = pick("red", "blue", "green", "purple")

/obj/item/twohanded/dualsaber/update_icon_state()
	if(wielded)
		icon_state = "dualsaber[blade_color][wielded]"
		set_light(brightness_on, l_color=colormap[blade_color])
	else
		icon_state = "dualsaber0"
		set_light(0)

/obj/item/twohanded/dualsaber/attack(mob/target, mob/living/user)
	if(HAS_TRAIT(user, TRAIT_HULK))
		to_chat(user, "<span class='warning'>You grip the blade too hard and accidentally close it!</span>")
		unwield()
		return
	..()
	if(HAS_TRAIT(user, TRAIT_CLUMSY) && (wielded) && prob(40))
		to_chat(user, "<span class='warning'>You twirl around a bit before losing your balance and impaling yourself on [src].</span>")
		user.take_organ_damage(20, 25)
		return
	if((wielded) && prob(50))
		INVOKE_ASYNC(src, PROC_REF(jedi_spin), user)

/obj/item/twohanded/dualsaber/proc/jedi_spin(mob/living/user)
	for(var/i in list(NORTH, SOUTH, EAST, WEST, EAST, SOUTH, NORTH, SOUTH, EAST, WEST, EAST, SOUTH))
		user.setDir(i)
		if(i == WEST)
			user.SpinAnimation(7, 1)
		sleep(1)

/obj/item/twohanded/dualsaber/hit_reaction(mob/living/carbon/human/owner, atom/movable/hitby, attack_text = "the attack", final_block_chance = 0, damage = 0, attack_type = MELEE_ATTACK)
	if(wielded)
		return ..()
	return FALSE

/obj/item/twohanded/dualsaber/attack_hulk(mob/living/carbon/human/user, does_attack_animation = FALSE)  //In case thats just so happens that it is still activated on the groud, prevents hulk from picking it up
	if(wielded)
		to_chat(user, "<span class='warning'>You can't pick up such a dangerous item with your meaty hands without losing fingers, better not to!</span>")
		return TRUE

/obj/item/twohanded/dualsaber/green
	blade_color = "green"

/obj/item/twohanded/dualsaber/red
	blade_color = "red"

/obj/item/twohanded/dualsaber/purple
	blade_color = "purple"

/obj/item/twohanded/dualsaber/blue
	blade_color = "blue"

/obj/item/twohanded/dualsaber/unwield()
	. = ..()
	if(!.)
		return
	hitsound = "swing_hit"
	w_class = initial(w_class)

/obj/item/twohanded/dualsaber/IsReflect()
	if(wielded)
		return TRUE

/obj/item/twohanded/dualsaber/wield(mob/living/carbon/M) //Specific wield () hulk checks due to reflection chance for balance issues and switches hitsounds.
	if(HAS_TRAIT(M, TRAIT_HULK))
		to_chat(M, "<span class='warning'>You lack the grace to wield this!</span>")
		return
	. = ..()
	if(!.)
		return
	hitsound = 'sound/weapons/blade1.ogg'
	w_class = w_class_on

/obj/item/twohanded/dualsaber/multitool_act(mob/user, obj/item/I)
	. = TRUE
	if(!I.use_tool(src, user, 0, volume = I.tool_volume))
		return
	if(!hacked)
		hacked = TRUE
		to_chat(user, "<span class='warning'>2XRNBW_ENGAGE</span>")
		blade_color = "rainbow"
		update_icon()
	else
		to_chat(user, "<span class='warning'>It's starting to look like a triple rainbow - no, nevermind.</span>")

//spears
/obj/item/twohanded/spear
	icon_state = "spearglass0"
	name = "spear"
	desc = "A haphazardly-constructed yet still deadly weapon of ancient design."
	force = 10
	w_class = WEIGHT_CLASS_BULKY
	slot_flags = SLOT_BACK
	force_unwielded = 10
	force_wielded = 18
	throwforce = 20
	throw_speed = 4
	armour_penetration_flat = 5
	materials = list(MAT_METAL = 1150, MAT_GLASS = 2075)
	hitsound = 'sound/weapons/bladeslice.ogg'
	attack_verb = list("attacked", "poked", "jabbed", "torn", "gored")
	sharp = TRUE
	no_spin_thrown = TRUE
	var/obj/item/grenade/explosive = null
	max_integrity = 200
	armor = list(MELEE = 0, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 0, BIO = 0, RAD = 0, FIRE = 50, ACID = 30)
	needs_permit = TRUE
	var/icon_prefix = "spearglass"

/obj/item/twohanded/spear/update_icon_state()
	icon_state = "[icon_prefix][wielded]"

/obj/item/twohanded/spear/CheckParts(list/parts_list)
	var/obj/item/shard/tip = locate() in parts_list
	if(istype(tip, /obj/item/shard/plasma))
		force_wielded = 19
		force_unwielded = 11
		throwforce = 21
		icon_prefix = "spearplasma"
	update_icon()
	qdel(tip)
	..()


/obj/item/twohanded/spear/afterattack(atom/movable/AM, mob/user, proximity)
	if(!proximity)
		return
	if(isturf(AM)) //So you can actually melee with it
		return
	if(explosive && wielded)
		explosive.forceMove(AM)
		explosive.prime()
		qdel(src)

/obj/item/twohanded/spear/throw_impact(atom/target)
	. = ..()
	if(explosive)
		explosive.prime()
		qdel(src)

/obj/item/twohanded/spear/bonespear	//Blatant imitation of spear, but made out of bone. Not valid for explosive modification.
	icon_state = "bone_spear0"
	name = "bone spear"
	desc = "A haphazardly-constructed yet still deadly weapon. The pinnacle of modern technology."
	force = 11
	force_unwielded = 11
	force_wielded = 20					//I have no idea how to balance
	throwforce = 22
	armour_penetration_percentage = 15				//Enhanced armor piercing
	icon_prefix = "bone_spear"

//GREY TIDE
/obj/item/twohanded/spear/grey_tide
	icon_state = "spearglass0"
	name = "\improper Grey Tide"
	desc = "Recovered from the aftermath of a revolt aboard Defense Outpost Theta Aegis, in which a seemingly endless tide of Assistants caused heavy casualities among Nanotrasen military forces."
	force_unwielded = 15
	force_wielded = 25
	throwforce = 20
	throw_speed = 4
	attack_verb = list("gored")

/obj/item/twohanded/spear/grey_tide/afterattack(atom/movable/AM, mob/living/user, proximity)
	..()
	if(!proximity)
		return
	user.faction |= "greytide(\ref[user])"
	if(isliving(AM))
		var/mob/living/L = AM
		if(istype (L, /mob/living/simple_animal/hostile/illusion))
			return
		if(!L.stat && prob(50))
			var/mob/living/simple_animal/hostile/illusion/M = new(user.loc)
			M.faction = user.faction.Copy()
			M.attack_sound = hitsound
			M.Copy_Parent(user, 100, user.health/2.5, 12, 30)
			M.GiveTarget(L)

//Putting heads on spears
/obj/item/twohanded/spear/attackby(obj/item/I, mob/living/user)
	if(istype(I, /obj/item/organ/external/head))
		if(user.unEquip(src) && user.drop_item())
			to_chat(user, "<span class='notice'>You stick [I] onto the spear and stand it upright on the ground.</span>")
			var/obj/structure/headspear/HS = new /obj/structure/headspear(get_turf(src))
			var/matrix/M = matrix()
			I.transform = M
			var/image/IM = image(I.icon, I.icon_state)
			IM.overlays = I.overlays.Copy()
			HS.overlays += IM
			I.forceMove(HS)
			HS.mounted_head = I
			forceMove(HS)
			HS.contained_spear = src
	else
		return ..()

/obj/structure/headspear
	name = "head on a spear"
	desc = "How barbaric."
	icon_state = "headspear"
	density = FALSE
	anchored = TRUE
	var/obj/item/organ/external/head/mounted_head = null
	var/obj/item/twohanded/spear/contained_spear = null

/obj/structure/headspear/Destroy()
	QDEL_NULL(mounted_head)
	QDEL_NULL(contained_spear)
	return ..()

/obj/structure/headspear/attack_hand(mob/living/user)
	user.visible_message("<span class='warning'>[user] kicks over [src]!</span>", "<span class='danger'>You kick down [src]!</span>")
	playsound(src, 'sound/weapons/genhit.ogg', 50, 1)
	var/turf/T = get_turf(src)
	if(contained_spear)
		contained_spear.forceMove(T)
		contained_spear = null
	if(mounted_head)
		mounted_head.forceMove(T)
		mounted_head = null
	qdel(src)

/obj/item/twohanded/spear/kidan
	icon_state = "kidanspear0"
	name = "\improper Kidan spear"
	desc = "A spear brought over from the Kidan homeworld."

// DIY CHAINSAW
/obj/item/twohanded/required/chainsaw
	name = "chainsaw"
	desc = "A versatile power tool. Useful for limbing trees and delimbing humans."
	icon_state = "gchainsaw_off"
	flags = CONDUCT
	force = 13
	var/force_on = 24
	w_class = WEIGHT_CLASS_HUGE
	throwforce = 13
	throw_speed = 2
	throw_range = 4
	materials = list(MAT_METAL = 13000)
	origin_tech = "materials=3;engineering=4;combat=2"
	attack_verb = list("sawed", "cut", "hacked", "carved", "cleaved", "butchered", "felled", "timbered")
	hitsound = "swing_hit"
	sharp = TRUE
	actions_types = list(/datum/action/item_action/startchainsaw)
	var/on = FALSE

/obj/item/twohanded/required/chainsaw/attack_self(mob/user)
	on = !on
	to_chat(user, "As you pull the starting cord dangling from [src], [on ? "it begins to whirr." : "the chain stops moving."]")
	if(on)
		playsound(loc, 'sound/weapons/chainsawstart.ogg', 50, 1)
	force = on ? force_on : initial(force)
	throwforce = on ? force_on : initial(throwforce)
	icon_state = "gchainsaw_[on ? "on" : "off"]"

	if(hitsound == "swing_hit")
		hitsound = 'sound/weapons/chainsaw.ogg'
	else
		hitsound = "swing_hit"

	if(src == user.get_active_hand()) //update inhands
		user.update_inv_l_hand()
		user.update_inv_r_hand()
	for(var/X in actions)
		var/datum/action/A = X
		A.UpdateButtonIcon()

/obj/item/twohanded/required/chainsaw/attack_hand(mob/user)
	. = ..()
	force = on ? force_on : initial(force)
	throwforce = on ? force_on : initial(throwforce)

/obj/item/twohanded/required/chainsaw/on_give(mob/living/carbon/giver, mob/living/carbon/receiver)
	. = ..()
	force = on ? force_on : initial(force)
	throwforce = on ? force_on : initial(throwforce)

/obj/item/twohanded/required/chainsaw/doomslayer
	name = "OOOH BABY"
	desc = "<span class='warning'>VRRRRRRR!!!</span>"
	armour_penetration_percentage = 100
	force_on = 30

/obj/item/twohanded/required/chainsaw/doomslayer/hit_reaction(mob/living/carbon/human/owner, atom/movable/hitby, attack_text = "the attack", final_block_chance = 0, damage = 0, attack_type = MELEE_ATTACK)
	if(attack_type == PROJECTILE_ATTACK)
		owner.visible_message("<span class='danger'>Ranged attacks just make [owner] angrier!</span>")
		playsound(src, pick('sound/weapons/bulletflyby.ogg','sound/weapons/bulletflyby2.ogg','sound/weapons/bulletflyby3.ogg'), 75, 1)
		return TRUE
	return FALSE


///CHAINSAW///
/obj/item/twohanded/chainsaw
	icon_state = "chainsaw0"
	name = "chainsaw"
	desc = "Perfect for felling trees or fellow spacemen."
	force = 15
	throwforce = 15
	throw_speed = 1
	throw_range = 5
	w_class = WEIGHT_CLASS_BULKY // can't fit in backpacks
	force_unwielded = 15 //still pretty robust
	force_wielded = 40  //you'll gouge their eye out! Or a limb...maybe even their entire body!
	hitsound = null // Handled in the snowflaked attack proc
	wieldsound = 'sound/weapons/chainsawstart.ogg'
	hitsound = null
	armour_penetration_percentage = 50
	armour_penetration_flat = 10
	origin_tech = "materials=6;syndicate=4"
	attack_verb = list("sawed", "cut", "hacked", "carved", "cleaved", "butchered", "felled", "timbered")
	sharp = TRUE

/obj/item/twohanded/chainsaw/update_icon_state()
	if(wielded)
		icon_state = "chainsaw[wielded]"
	else
		icon_state = "chainsaw0"

/obj/item/twohanded/chainsaw/attack(mob/living/target, mob/living/user)
	. = ..()
	if(wielded)
		playsound(loc, 'sound/weapons/chainsaw.ogg', 100, 1, -1) //incredibly loud; you ain't goin' for stealth with this thing. Credit to Lonemonk of Freesound for this sound.
		if(isnull(.)) //necessary check, successful attacks return null, without it target will drop any shields they may have before they get a chance to block
			target.KnockDown(8 SECONDS)

/obj/item/twohanded/chainsaw/afterattack(mob/living/target, mob/living/user, proximity)
	if(!proximity) //only works on adjacent targets, no telekinetic chainsaws
		return
	if(!wielded)
		return
	if(isrobot(target)) //no buff from attacking robots
		return
	if(!isliving(target)) //no buff from attacking inanimate objects
		return
	if(target.stat != DEAD) //no buff from attacking dead targets
		user.apply_status_effect(STATUS_EFFECT_CHAINSAW_SLAYING)

/obj/item/twohanded/chainsaw/hit_reaction(mob/living/carbon/human/owner, atom/movable/hitby, attack_text = "the attack", final_block_chance = 0, damage = 0, attack_type = MELEE_ATTACK)
	if(attack_type == PROJECTILE_ATTACK)
		final_block_chance = 0 //It's a chainsaw, you try blocking bullets with it
	else if(owner.has_status_effect(STATUS_EFFECT_CHAINSAW_SLAYING))
		final_block_chance = 80 //Need to be ready to ruuuummbllleeee
	return ..()

/obj/item/twohanded/chainsaw/wield() //you can't disarm an active chainsaw, you crazy person.
	. = ..()
	if(.)
		flags |= NODROP

/obj/item/twohanded/chainsaw/unwield()
	. = ..()
	if(.)
		flags &= ~NODROP

/obj/item/twohanded/chainsaw/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_BUTCHERS_HUMANS, ROUNDSTART_TRAIT)

// SINGULOHAMMER
/obj/item/twohanded/singularityhammer
	name = "singularity hammer"
	desc = "The pinnacle of close combat technology, the hammer harnesses the power of a miniaturized singularity to deal crushing blows."
	icon_state = "singulohammer0"
	flags = CONDUCT
	slot_flags = SLOT_BACK
	force = 5
	force_unwielded = 5
	force_wielded = 40
	throwforce = 15
	throw_range = 1
	w_class = WEIGHT_CLASS_HUGE
	armor = list(MELEE = 50, BULLET = 50, LASER = 50, ENERGY = 0, BOMB = 50, BIO = 0, RAD = 0, FIRE = 100, ACID = 100)
	resistance_flags = FIRE_PROOF | ACID_PROOF
	var/charged = 2
	origin_tech = "combat=4;bluespace=4;plasmatech=7"

/obj/item/twohanded/singularityhammer/New()
	..()
	START_PROCESSING(SSobj, src)

/obj/item/twohanded/singularityhammer/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/twohanded/singularityhammer/process()
	if(charged < 2)
		charged++

/obj/item/twohanded/singularityhammer/update_icon_state()  //Currently only here to fuck with the on-mob icons.
	icon_state = "singulohammer[wielded]"

/obj/item/twohanded/singularityhammer/proc/vortex(turf/pull, mob/wielder)
	for(var/atom/movable/X in orange(5, pull))
		if(X.move_resist == INFINITY)
			continue
		if(X == wielder)
			continue
		if((X) && (!X.anchored) && (!ishuman(X)))
			step_towards(X, pull)
			step_towards(X, pull)
			step_towards(X, pull)
		else if(ishuman(X))
			var/mob/living/carbon/human/H = X
			if(istype(H.shoes, /obj/item/clothing/shoes/magboots))
				var/obj/item/clothing/shoes/magboots/M = H.shoes
				if(M.magpulse)
					continue
			H.Weaken(4 SECONDS)
			step_towards(H, pull)
			step_towards(H, pull)
			step_towards(H, pull)

/obj/item/twohanded/singularityhammer/afterattack(atom/A, mob/user, proximity)
	if(!proximity)
		return
	if(wielded)
		if(charged == 2)
			charged = 0
			if(isliving(A))
				var/mob/living/Z = A
				Z.take_organ_damage(20, 0)
			playsound(user, 'sound/weapons/marauder.ogg', 50, 1)
			var/turf/target = get_turf(A)
			vortex(target, user)

/obj/item/twohanded/mjollnir
	name = "Mjolnir"
	desc = "A weapon worthy of a god, able to strike with the force of a lightning bolt. It crackles with barely contained energy."
	icon_state = "mjollnir0"
	flags = CONDUCT
	slot_flags = SLOT_BACK
	force = 5
	force_unwielded = 5
	force_wielded = 25
	throwforce = 30
	throw_range = 7
	w_class = WEIGHT_CLASS_HUGE
	//var/charged = 5
	origin_tech = "combat=4;powerstorage=7"

/obj/item/twohanded/mjollnir/proc/shock(mob/living/target)
	do_sparks(5, 1, target.loc)
	target.visible_message("<span class='danger'>[target] was shocked by [src]!</span>",
		"<span class='userdanger'>You feel a powerful shock course through your body sending you flying!</span>",
		"<span class='danger'>You hear a heavy electrical crack!</span>")
	var/atom/throw_target = get_edge_target_turf(target, get_dir(src, get_step_away(target, src)))
	target.throw_at(throw_target, 200, 4)

/obj/item/twohanded/mjollnir/attack(mob/living/M, mob/user)
	..()
	if(wielded)
		//if(charged == 5)
		//charged = 0
		playsound(loc, "sparks", 50, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
		M.Stun(6 SECONDS)
		shock(M)

/obj/item/twohanded/mjollnir/throw_impact(atom/target)
	. = ..()
	if(isliving(target))
		var/mob/living/L = target
		L.Stun(6 SECONDS)
		shock(L)

/obj/item/twohanded/mjollnir/update_icon_state()  //Currently only here to fuck with the on-mob icons.
	icon_state = "mjollnir[wielded]"

/obj/item/twohanded/knighthammer
	name = "singuloth knight's hammer"
	desc = "A hammer made of sturdy metal with a golden skull adorned with wings on either side of the head. <br>This weapon causes devastating damage to those it hits due to a power field sustained by a mini-singularity inside of the hammer."
	icon_state = "knighthammer0"
	flags = CONDUCT
	slot_flags = SLOT_BACK
	force = 5
	force_unwielded = 5
	force_wielded = 30
	throwforce = 15
	throw_range = 1
	w_class = WEIGHT_CLASS_HUGE
	var/charged = 5
	origin_tech = "combat=5;bluespace=4"

/obj/item/twohanded/knighthammer/New()
	..()
	START_PROCESSING(SSobj, src)

/obj/item/twohanded/knighthammer/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/twohanded/knighthammer/process()
	if(charged < 5)
		charged++

/obj/item/twohanded/knighthammer/update_icon_state()  //Currently only here to fuck with the on-mob icons.
	icon_state = "knighthammer[wielded]"

/obj/item/twohanded/knighthammer/afterattack(atom/A, mob/user, proximity)
	if(!proximity)
		return
	if(charged == 5)
		charged = 0
		if(isliving(A))
			var/mob/living/Z = A
			if(Z.health >= 1)
				Z.visible_message("<span class='danger'>[Z.name] was sent flying by a blow from [src]!</span>",
					"<span class='userdanger'>You feel a powerful blow connect with your body and send you flying!</span>",
					"<span class='danger'>You hear something heavy impact flesh!.</span>")
				var/atom/throw_target = get_edge_target_turf(Z, get_dir(src, get_step_away(Z, src)))
				Z.throw_at(throw_target, 200, 4)
				playsound(user, 'sound/weapons/marauder.ogg', 50, 1)
			else if(wielded && Z.health < 1)
				Z.visible_message("<span class='danger'>[Z.name] was blown to pieces by the power of [src]!</span>",
					"<span class='userdanger'>You feel a powerful blow rip you apart!</span>",
					"<span class='danger'>You hear a heavy impact and the sound of ripping flesh!.</span>")
				Z.gib()
				playsound(user, 'sound/weapons/marauder.ogg', 50, 1)
		if(wielded)
			if(iswallturf(A))
				var/turf/simulated/wall/Z = A
				Z.ex_act(2)
				charged = 3
				playsound(user, 'sound/weapons/marauder.ogg', 50, 1)
			else if(isstructure(A) || ismecha(A))
				var/obj/Z = A
				Z.ex_act(2)
				charged = 3
				playsound(user, 'sound/weapons/marauder.ogg', 50, 1)

// PYRO CLAWS
/obj/item/twohanded/required/pyro_claws
	name = "hardplasma energy claws"
	desc = "The power of the sun, in the claws of your hand."
	icon_state = "pyro_claws"
	flags = ABSTRACT | NODROP | DROPDEL
	force = 22
	force_wielded = 22
	damtype = BURN
	armour_penetration_percentage = 50
	block_chance = 50
	sharp = TRUE
	attack_effect_override = ATTACK_EFFECT_CLAW
	hitsound = 'sound/weapons/bladeslice.ogg'
	attack_verb = list("slashed", "stabbed", "sliced", "torn", "ripped", "diced", "cut", "savaged", "clawed")
	sprite_sheets_inhand = list("Vox" = 'icons/mob/clothing/species/vox/held.dmi', "Drask" = 'icons/mob/clothing/species/drask/held.dmi')
	toolspeed = 0.5
	var/lifetime = 60 SECONDS

/obj/item/twohanded/required/pyro_claws/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/twohanded/required/pyro_claws/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/twohanded/required/pyro_claws/process()
	lifetime -= 2 SECONDS
	if(lifetime <= 0)
		visible_message("<span class='warning'>[src] slides back into the depths of [loc]'s wrists.</span>")
		do_sparks(rand(1,6), 1, loc)
		qdel(src)
		return
	if(prob(15))
		do_sparks(rand(1,6), 1, loc)

/obj/item/twohanded/required/pyro_claws/afterattack(atom/target, mob/user, proximity)
	if(!proximity)
		return
	if(prob(60))
		do_sparks(rand(1,6), 1, loc)
	if(istype(target, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/A = target

		if(!A.requiresID() || A.allowed(user))
			return

		if(A.locked)
			to_chat(user, "<span class='notice'>The airlock's bolts prevent it from being forced.</span>")
			return

		if(A.arePowerSystemsOn())
			user.visible_message("<span class='warning'>[user] jams [user.p_their()] [name] into the airlock and starts prying it open!</span>", "<span class='warning'>You start forcing the airlock open.</span>", "<span class='warning'>You hear a metal screeching sound.</span>")
			playsound(A, 'sound/machines/airlock_alien_prying.ogg', 150, 1)
			if(!do_after(user, 25, target = A))
				return

		user.visible_message("<span class='warning'>[user] forces the airlock open with [user.p_their()] [name]!</span>", "<span class='warning'>You force open the airlock.</span>", "<span class='warning'>You hear a metal screeching sound.</span>")
		A.open(2)

/obj/item/clothing/gloves/color/black/pyro_claws
	name = "Fusion gauntlets"
	desc = "Cybersun Industries developed these gloves after a grifter fought one of their soldiers, who attached a pyro core to an energy sword, and found it mostly effective."
	item_state = "pyro"
	item_color = "pyro" // I will kill washing machines one day
	icon_state = "pyro"
	can_be_cut = FALSE
	actions_types = list(/datum/action/item_action/toggle)
	var/on_cooldown = FALSE
	var/obj/item/assembly/signaler/anomaly/pyro/core

/obj/item/clothing/gloves/color/black/pyro_claws/Destroy()
	QDEL_NULL(core)
	return ..()

/obj/item/clothing/gloves/color/black/pyro_claws/examine(mob/user)
	. = ..()
	if(core)
		. += "<span class='notice'>[src] are fully operational!</span>"
	else
		. += "<span class='warning'>It is missing a pyroclastic anomaly core.</span>"

/obj/item/clothing/gloves/color/black/pyro_claws/item_action_slot_check(slot)
	if(slot == slot_gloves)
		return TRUE

/obj/item/clothing/gloves/color/black/pyro_claws/ui_action_click(mob/user)
	if(!core)
		to_chat(user, "<span class='notice'>[src] has no core to power it!</span>")
		return
	if(on_cooldown)
		to_chat(user, "<span class='notice'>[src] is on cooldown!</span>")
		do_sparks(rand(1,6), 1, loc)
		return
	if(!user.drop_l_hand() || !user.drop_r_hand())
		to_chat(user, "<span class='notice'>[src] are unable to deploy the blades with the items in your hands!</span>")
		return
	var/obj/item/W = new /obj/item/twohanded/required/pyro_claws
	user.visible_message("<span class='warning'>[user] deploys [W] from [user.p_their()] wrists in a shower of sparks!</span>", "<span class='notice'>You deploy [W] from your wrists!</span>", "<span class='warning'>You hear the shower of sparks!</span>")
	user.put_in_hands(W)
	on_cooldown = TRUE
	flags |= NODROP
	addtimer(CALLBACK(src, PROC_REF(reboot)), 2 MINUTES)
	do_sparks(rand(1,6), 1, loc)

/obj/item/clothing/gloves/color/black/pyro_claws/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/assembly/signaler/anomaly/pyro))
		if(core)
			to_chat(user, "<span class='notice'>[src] already has a [I]!</span>")
			return
		if(!user.drop_item())
			to_chat(user, "<span class='warning'>[I] is stuck to your hand!</span>")
			return
		to_chat(user, "<span class='notice'>You insert [I] into [src], and [src] starts to warm up.</span>")
		I.forceMove(src)
		core = I
	else
		return ..()

/obj/item/clothing/gloves/color/black/pyro_claws/proc/reboot()
	on_cooldown = FALSE
	flags &= ~NODROP
	atom_say("Internal plasma canisters recharged. Gloves sufficiently cooled")

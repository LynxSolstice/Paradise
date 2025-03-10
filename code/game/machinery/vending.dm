/**
 *  Datum used to hold information about a product in a vending machine
 */
/datum/data/vending_product
	name = "generic"
	///Typepath of the product that is created when this record "sells"
	var/product_path = null
	///How many of this product we currently have
	var/amount = 0
	///How many we can store at maximum
	var/max_amount = 0
	var/price = 0  // Price to buy one

/obj/machinery/vending
	name = "\improper Vendomat"
	desc = "A generic vending machine."
	icon = 'icons/obj/vending.dmi'
	icon_state = "generic"
	layer = BELOW_OBJ_LAYER
	anchored = TRUE
	density = TRUE
	face_while_pulling = TRUE
	max_integrity = 300
	integrity_failure = 100
	armor = list(melee = 20, bullet = 0, laser = 0, energy = 0, bomb = 0, bio = 0, rad = 0, fire = 50, acid = 70)
	/// Icon_state when vending
	var/icon_vend
	/// Icon_state when denying access
	var/icon_deny
	/// Icon to be an overlay over the base sprite
	var/icon_addon
	/// Icon for the broken overlay, defaults to icon_state + _broken
	var/icon_broken
	/// Icon for the off overlay, defaults to icon_state + _off
	var/icon_off
	/// Icon for the panel overlay, defaults to icon_state + _panel
	var/icon_panel
	/// Icon for the lightmask, defaults to icon_state + _off, _lightmask if one is defined.
	var/icon_lightmask
	// Power
	use_power = IDLE_POWER_USE
	idle_power_usage = 10
	var/vend_power_usage = 150

	var/light_range_on = 1
	var/light_power_on = 0.5

	// Vending-related
	/// No sales pitches if off
	var/active = TRUE
	/// If off, vendor is busy and unusable until current action finishes
	var/vend_ready = TRUE
	/// How long vendor takes to vend one item.
	var/vend_delay = 10
	/// Item currently being bought
	var/datum/data/vending_product/currently_vending = null

	// To be filled out at compile time
	var/list/products	= list()	// For each, use the following pattern:
	var/list/contraband	= list()	// list(/type/path = amount,/type/path2 = amount2)
	var/list/premium 	= list()	// No specified amount = only one in stock
	var/list/prices     = list()	// Prices for each item, list(/type/path = price), items not in the list don't have a price.

	// List of vending_product items available.
	var/list/product_records = list()
	var/list/hidden_records = list()
	var/list/coin_records = list()
	var/list/imagelist = list()

	/// Unimplemented list of ads that are meant to show up somewhere, but don't.
	var/list/ads_list = list()

	// Stuff relating vocalizations
	/// List of slogans the vendor will say, optional
	var/list/slogan_list = list()
	var/vend_reply				//Thank you for shopping!
	/// If true, prevent saying sales pitches
	var/shut_up = FALSE
	///can we access the hidden inventory?
	var/extended_inventory = FALSE
	var/last_reply = 0
	var/last_slogan = 0			//When did we last pitch?
	var/slogan_delay = 6000		//How long until we can pitch again?

	//The type of refill canisters used by this machine.
	var/obj/item/vending_refill/refill_canister = null

	// Things that can go wrong
	/// Allows people to access a vendor that's normally access restricted.
	emagged = FALSE
	/// Shocks people like an airlock
	var/seconds_electrified = 0
	/// Fire items at customers! We're broken!
	var/shoot_inventory = FALSE
	/// How hard are we firing the items?
	var/shoot_speed = 3
	/// How often are we firing the items? (prob(...))
	var/shoot_chance = 2

	/// If true, enforce access checks on customers. Disabled by messing with wires.
	var/scan_id = TRUE
	/// Holder for a coin inserted into the vendor
	var/obj/item/coin/coin
	var/datum/wires/vending/wires = null

	/// boolean, whether this vending machine can accept people inserting items into it, used for coffee vendors
	var/item_slot = FALSE
	/// the actual item inserted
	var/obj/item/inserted_item = null

	/// blocks further flickering while true
	var/flickering = FALSE
	/// do I look unpowered, even when powered?
	var/force_no_power_icon_state = FALSE

/obj/machinery/vending/Initialize(mapload)
	. = ..()
	var/build_inv = FALSE
	if(!refill_canister)
		build_inv = TRUE
	else
		component_parts = list()
		var/obj/item/circuitboard/vendor/V = new
		V.set_type(replacetext(initial(name), "\improper", ""))
		component_parts += V
		component_parts += new refill_canister
		RefreshParts()

	wires = new(src)
	if(build_inv) //non-constructable vending machine
		build_inventory(products, product_records)
		build_inventory(contraband, hidden_records)
		build_inventory(premium, coin_records)
	for(var/datum/data/vending_product/R in (product_records + coin_records + hidden_records))
		var/obj/item/I = R.product_path
		var/pp = replacetext(replacetext("[R.product_path]", "/obj/item/", ""), "/", "-")
		imagelist[pp] = "[icon2base64(icon(initial(I.icon), initial(I.icon_state), SOUTH, 1))]"
	if(LAZYLEN(slogan_list))
		// So not all machines speak at the exact same time.
		// The first time this machine says something will be at slogantime + this random value,
		// so if slogantime is 10 minutes, it will say it at somewhere between 10 and 20 minutes after the machine is created.
		last_slogan = world.time + rand(0, slogan_delay)

	power_change()

/obj/machinery/vending/Destroy()
	SStgui.close_uis(wires)
	QDEL_NULL(wires)
	QDEL_NULL(coin)
	QDEL_NULL(inserted_item)
	return ..()

/obj/machinery/vending/RefreshParts()         //Better would be to make constructable child
	if(!component_parts)
		return

	product_records = list()
	hidden_records = list()
	coin_records = list()
	if(refill_canister)
		build_inventory(products, product_records, start_empty = TRUE)
		build_inventory(contraband, hidden_records, start_empty = TRUE)
		build_inventory(premium, coin_records, start_empty = TRUE)
	for(var/obj/item/vending_refill/VR in component_parts)
		restock(VR)

/obj/machinery/vending/update_overlays()
	. = ..()
	underlays.Cut()
	if(panel_open)
		. += "[icon_panel ? "[icon_panel]_panel" : "[icon_state]_panel"]"
	if(icon_addon)
		. += "[icon_addon]"
	if((stat & (BROKEN|NOPOWER)) || force_no_power_icon_state)
		. += "[icon_off ? "[icon_off]_off" : "[icon_state]_off"]"
		if(stat & BROKEN)
			. += "[icon_broken ? "[icon_broken]_broken" : "[icon_state]_broken"]"
		return
	if(light)
		underlays += emissive_appearance(icon, "[icon_lightmask ? "[icon_lightmask]_lightmask" : "[icon_state]_off"]")

/*
 * Reimp, flash the screen on and off repeatedly.
 */
/obj/machinery/vending/flicker()
	if(flickering)
		return FALSE

	if(stat & (BROKEN|NOPOWER))
		return FALSE

	flickering = TRUE
	INVOKE_ASYNC(src, TYPE_PROC_REF(/obj/machinery/vending, flicker_event))

	return TRUE

/*
 * Proc to be called by invoke_async in the above flicker() proc.
 */
/obj/machinery/vending/proc/flicker_event()
	var/amount = rand(5, 15)

	for(var/i in 1 to amount)
		force_no_power_icon_state = TRUE
		set_light(0)
		update_icon(UPDATE_OVERLAYS)
		sleep(rand(1, 3))

		force_no_power_icon_state = FALSE
		set_light(light_range_on, light_power_on)
		update_icon(UPDATE_OVERLAYS)
		sleep(rand(1, 10))
	update_icon(UPDATE_OVERLAYS)
	flickering = FALSE

/**
 *  Build src.produdct_records from the products lists
 *
 *  src.products, src.contraband, src.premium, and src.prices allow specifying
 *  products that the vending machine is to carry without manually populating
 *  src.product_records.
 */
/obj/machinery/vending/proc/build_inventory(list/productlist, list/recordlist, start_empty = FALSE)
	for(var/typepath in productlist)
		var/amount = productlist[typepath]
		if(isnull(amount))
			amount = 0

		var/atom/temp = typepath
		var/datum/data/vending_product/R = new /datum/data/vending_product()
		R.name = initial(temp.name)
		R.product_path = typepath
		if(!start_empty)
			R.amount = amount
		R.max_amount = amount
		R.price = (typepath in prices) ? prices[typepath] : 0
		recordlist += R
/**
  * Refill a vending machine from a refill canister
  *
  * This takes the products from the refill canister and then fills the products,contraband and premium product categories
  *
  * Arguments:
  * * canister - the vending canister we are refilling from
  */
/obj/machinery/vending/proc/restock(obj/item/vending_refill/canister)
	if(!canister.products)
		canister.products = products.Copy()
	if(!canister.contraband)
		canister.contraband = contraband.Copy()
	if(!canister.premium)
		canister.premium = premium.Copy()
	. = 0
	. += refill_inventory(canister.products, product_records)
	. += refill_inventory(canister.contraband, hidden_records)
	. += refill_inventory(canister.premium, coin_records)
/**
  * Refill our inventory from the passed in product list into the record list
  *
  * Arguments:
  * * productlist - list of types -> amount
  * * recordlist - existing record datums
  */
/obj/machinery/vending/proc/refill_inventory(list/productlist, list/recordlist)
	. = 0
	for(var/R in recordlist)
		var/datum/data/vending_product/record = R
		var/diff = min(record.max_amount - record.amount, productlist[record.product_path])
		if (diff)
			productlist[record.product_path] -= diff
			record.amount += diff
			. += diff
/**
  * Set up a refill canister that matches this machines products
  *
  * This is used when the machine is deconstructed, so the items aren't "lost"
  */
/obj/machinery/vending/proc/update_canister()
	if(!component_parts)
		return

	var/obj/item/vending_refill/R = locate() in component_parts
	if(!R)
		CRASH("Constructible vending machine did not have a refill canister")

	R.products = unbuild_inventory(product_records)
	R.contraband = unbuild_inventory(hidden_records)
	R.premium = unbuild_inventory(coin_records)

/**
  * Given a record list, go through and and return a list of type -> amount
  */
/obj/machinery/vending/proc/unbuild_inventory(list/recordlist)
	. = list()
	for(var/R in recordlist)
		var/datum/data/vending_product/record = R
		.[record.product_path] += record.amount

/obj/machinery/vending/deconstruct(disassembled = TRUE)
	eject_item()
	if(!refill_canister) //the non constructable vendors drop metal instead of a machine frame.
		new /obj/item/stack/sheet/metal(loc, 3)
		qdel(src)
	else
		..()

/obj/machinery/vending/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/coin))
		if(!premium.len)
			to_chat(user, "<span class='warning'>[src] does not accept coins.</span>")
			return
		if(coin)
			to_chat(user, "<span class='warning'>There is already a coin in this machine!</span>")
			return
		if(!user.drop_item())
			return
		I.forceMove(src)
		coin = I
		to_chat(user, "<span class='notice'>You insert [I] into [src].</span>")
		SStgui.update_uis(src)
		return
	if(refill_canister && istype(I, refill_canister))
		if(!panel_open)
			to_chat(user, "<span class='warning'>You should probably unscrew the service panel first!</span>")
		else if (stat & (BROKEN|NOPOWER))
			to_chat(user, "<span class='notice'>[src] does not respond.</span>")
		else
			//if the panel is open we attempt to refill the machine
			var/obj/item/vending_refill/canister = I
			if(canister.get_part_rating() == 0)
				to_chat(user, "<span class='warning'>[canister] is empty!</span>")
			else
				// instantiate canister if needed
				var/transferred = restock(canister)
				if(transferred)
					to_chat(user, "<span class='notice'>You loaded [transferred] items in [src].</span>")
				else
					to_chat(user, "<span class='warning'>There's nothing to restock!</span>")
		return
	if(item_slot_check(user, I))
		insert_item(user, I)
		return
	return ..()



/obj/machinery/vending/crowbar_act(mob/user, obj/item/I)
	if(!component_parts)
		return
	. = TRUE
	default_deconstruction_crowbar(user, I)

/obj/machinery/vending/multitool_act(mob/user, obj/item/I)
	. = TRUE
	if(!I.use_tool(src, user, 0, volume = I.tool_volume))
		return
	wires.Interact(user)

/obj/machinery/vending/screwdriver_act(mob/user, obj/item/I)
	. = TRUE
	if(!I.use_tool(src, user, 0, volume = I.tool_volume))
		return
	if(anchored)
		panel_open = !panel_open
		panel_open ? SCREWDRIVER_OPEN_PANEL_MESSAGE : SCREWDRIVER_CLOSE_PANEL_MESSAGE
		update_icon(UPDATE_OVERLAYS)
		SStgui.update_uis(src)

/obj/machinery/vending/wirecutter_act(mob/user, obj/item/I)
	. = TRUE
	if(I.use_tool(src, user, 0, volume = 0))
		wires.Interact(user)

/obj/machinery/vending/wrench_act(mob/user, obj/item/I)
	. = TRUE
	if(!I.use_tool(src, user, 0, volume = 0))
		return
	default_unfasten_wrench(user, I, time = 60)

//Override this proc to do per-machine checks on the inserted item, but remember to call the parent to handle these generic checks before your logic!
/obj/machinery/vending/proc/item_slot_check(mob/user, obj/item/I)
	if(!item_slot)
		return FALSE
	if(inserted_item)
		to_chat(user, "<span class='warning'>There is something already inserted!</span>")
		return FALSE
	return TRUE

/* Example override for item_slot_check proc:
/obj/machinery/vending/example/item_slot_check(mob/user, obj/item/I)
	if(!..())
		return FALSE
	if(!istype(I, /obj/item/toy))
		to_chat(user, "<span class='warning'>[I] isn't compatible with this machine's slot.</span>")
		return FALSE
	return TRUE
*/

/obj/machinery/vending/exchange_parts(mob/user, obj/item/storage/part_replacer/W)
	if(!istype(W))
		return FALSE
	if(!W.works_from_distance)
		return FALSE
	if(!component_parts || !refill_canister)
		return FALSE

	var/moved = 0
	if(panel_open || W.works_from_distance)
		if(W.works_from_distance)
			to_chat(user, display_parts(user))
		for(var/I in W)
			if(istype(I, refill_canister))
				moved += restock(I)
	else
		to_chat(user, display_parts(user))
	if(moved)
		to_chat(user, "[moved] items restocked.")
		W.play_rped_sound()
	return TRUE

/obj/machinery/vending/on_deconstruction()
	update_canister()
	. = ..()

/obj/machinery/vending/proc/insert_item(mob/user, obj/item/I)
	if(!item_slot || inserted_item)
		return
	if(!user.drop_item())
		to_chat(user, "<span class='warning'>[I] is stuck to your hand, you can't seem to put it down!</span>")
		return
	inserted_item = I
	I.forceMove(src)
	to_chat(user, "<span class='notice'>You insert [I] into [src].</span>")
	SStgui.update_uis(src)

/obj/machinery/vending/proc/eject_item(mob/user)
	if(!item_slot || !inserted_item)
		return
	var/put_on_turf = TRUE
	if(user && iscarbon(user) && user.Adjacent(src))
		if(user.put_in_hands(inserted_item))
			put_on_turf = FALSE
	if(put_on_turf)
		var/turf/T = get_turf(src)
		inserted_item.forceMove(T)
	inserted_item = null
	SStgui.update_uis(src)

/obj/machinery/vending/emag_act(user as mob)
	emagged = TRUE
	to_chat(user, "You short out the product lock on [src]")


/obj/machinery/vending/proc/pay_with_cash(obj/item/stack/spacecash/cashmoney, mob/user)
	if(currently_vending.price > cashmoney.amount)
		// This is not a status display message, since it's something the character
		// themselves is meant to see BEFORE putting the money in
		to_chat(usr, "[bicon(cashmoney)] <span class='warning'>That is not enough money.</span>")
		return FALSE

	// Bills (banknotes) cannot really have worth different than face value,
	// so we have to eat the bill and spit out change in a bundle
	// This is really dirty, but there's no superclass for all bills, so we
	// just assume that all spacecash that's not something else is a bill

	visible_message("<span class='info'>[usr] inserts a credit chip into [src].</span>")
	cashmoney.use(currently_vending.price)

	// Vending machines have no idea who paid with cash
	GLOB.vendor_account.credit(currently_vending.price, "Sale of [currently_vending.name]",	name, "(cash)")
	return TRUE


/obj/machinery/vending/proc/pay_with_card(obj/item/card/id/I, mob/M)
	visible_message("<span class='info'>[M] swipes a card through [src].</span>")
	return pay_with_account(get_card_account(I), M)

/obj/machinery/vending/proc/pay_with_account(datum/money_account/customer_account, mob/M)
	if(!customer_account)
		to_chat(M, "<span class='warning'>Error: Unable to access account. Please contact technical support if problem persists.</span>")
		return FALSE
	if(customer_account.suspended)
		to_chat(M, "<span class='warning'>Unable to access account: account suspended.</span>")
		return FALSE
	// Have the customer punch in the PIN before checking if there's enough money.
	// Prevents people from figuring out acct is empty at high security levels
	if(customer_account.security_level != 0)
		// If card requires pin authentication (ie seclevel 1 or 2)
		var/attempt_pin = input("Enter pin code", "Vendor transaction") as num
		if(!attempt_account_access(customer_account.account_number, attempt_pin, 2))
			to_chat(M, "<span class='warning'>Unable to access account: incorrect credentials.</span>")
			return FALSE
	if(currently_vending.price > customer_account.money)
		to_chat(M, "<span class='warning'>Your bank account has insufficient money to purchase this.</span>")
		return FALSE
	// Okay to move the money at this point
	customer_account.charge(currently_vending.price, GLOB.vendor_account,
		"Purchase of [currently_vending.name]", name, GLOB.vendor_account.owner_name,
		"Sale of [currently_vending.name]", customer_account.owner_name)
	return TRUE


/obj/machinery/vending/attack_ai(mob/user)
	return attack_hand(user)

/obj/machinery/vending/attack_ghost(mob/user)
	return attack_hand(user)

/obj/machinery/vending/attack_hand(mob/user)
	if(stat & (BROKEN|NOPOWER))
		return

	if(src.seconds_electrified != 0)
		if(src.shock(user, 100))
			return

	ui_interact(user)
	wires.Interact(user)

/obj/machinery/vending/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = TRUE, datum/tgui/master_ui = null, datum/ui_state/state = GLOB.default_state)
	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		var/estimated_height = 100 + min(length(product_records) * 34, 500)
		if(length(prices) > 0)
			estimated_height += 100 // to account for the "current user" interface
		ui = new(user, src, ui_key, "Vending",  name, 470, estimated_height, master_ui, state)
		ui.open()

/obj/machinery/vending/ui_data(mob/user)
	var/list/data = list()
	var/mob/living/carbon/human/H
	var/obj/item/card/id/C
	data["guestNotice"] = "No valid ID card detected. Wear your ID, or present cash.";
	data["userMoney"] = 0
	data["user"] = null
	if(ishuman(user))
		H = user
		C = H.get_idcard(TRUE)
		if(!C && istype(H.wear_pda, /obj/item/pda))
			var/obj/item/pda/P = H.wear_pda
			if(istype(P.id, /obj/item/card/id))
				C = P.id
		var/obj/item/stack/spacecash/S = H.get_active_hand()
		if(istype(S))
			data["userMoney"] = S.amount
			data["guestNotice"] = "Accepting Cash. You have: [S.amount] credits."
		else if(istype(C))
			var/datum/money_account/A = get_card_account(C)
			if(istype(A))
				data["user"] = list()
				data["user"]["name"] = A.owner_name
				data["userMoney"] = A.money
				data["user"]["job"] = (istype(C) && C.rank) ? C.rank : "No Job"
			else
				data["guestNotice"] = "Unlinked ID detected. Present cash to pay.";
	data["stock"] = list()
	for (var/datum/data/vending_product/R in product_records + coin_records + hidden_records)
		data["stock"][R.name] = R.amount
	data["extended_inventory"] = extended_inventory
	data["vend_ready"] = vend_ready
	data["coin_name"] = coin ? coin.name : FALSE
	data["panel_open"] = panel_open ? TRUE : FALSE
	data["speaker"] = shut_up ? FALSE : TRUE
	data["item_slot"] = item_slot // boolean
	data["inserted_item_name"] = inserted_item ? inserted_item.name : FALSE
	return data


/obj/machinery/vending/ui_static_data(mob/user)
	var/list/data = list()
	data["chargesMoney"] = length(prices) > 0 ? TRUE : FALSE
	data["product_records"] = list()
	var/i = 1
	for (var/datum/data/vending_product/R in product_records)
		var/list/data_pr = list(
			path = replacetext(replacetext("[R.product_path]", "/obj/item/", ""), "/", "-"),
			name = R.name,
			price = (R.product_path in prices) ? prices[R.product_path] : 0,
			max_amount = R.max_amount,
			req_coin = FALSE,
			is_hidden = FALSE,
			inum = i
		)
		data["product_records"] += list(data_pr)
		i++
	data["coin_records"] = list()
	for (var/datum/data/vending_product/R in coin_records)
		var/list/data_cr = list(
			path = replacetext(replacetext("[R.product_path]", "/obj/item/", ""), "/", "-"),
			name = R.name,
			price = (R.product_path in prices) ? prices[R.product_path] : 0,
			max_amount = R.max_amount,
			req_coin = TRUE,
			is_hidden = FALSE,
			inum = i,
			premium = TRUE
		)
		data["coin_records"] += list(data_cr)
		i++
	data["hidden_records"] = list()
	for (var/datum/data/vending_product/R in hidden_records)
		var/list/data_hr = list(
			path = replacetext(replacetext("[R.product_path]", "/obj/item/", ""), "/", "-"),
			name = R.name,
			price = (R.product_path in prices) ? prices[R.product_path] : 0,
			max_amount = R.max_amount,
			req_coin = FALSE,
			is_hidden = TRUE,
			inum = i,
			premium = TRUE
		)
		data["hidden_records"] += list(data_hr)
		i++
	data["imagelist"] = imagelist
	return data

/obj/machinery/vending/ui_act(action, params)
	. = ..()
	if(.)
		return
	if(issilicon(usr) && !isrobot(usr))
		to_chat(usr, "<span class='warning'>The vending machine refuses to interface with you, as you are not in its target demographic!</span>")
		return
	switch(action)
		if("toggle_voice")
			if(panel_open)
				shut_up = !shut_up
				. = TRUE
		if("eject_item")
			eject_item(usr)
			. = TRUE
		if("remove_coin")
			if(!coin)
				to_chat(usr, "<span class='warning'>There is no coin in this machine.</span>")
				return
			if(issilicon(usr))
				to_chat(usr, "<span class='warning'>You lack hands.</span>")
				return
			to_chat(usr, "<span class='notice'>You remove [coin] from [src].</span>")
			usr.put_in_hands(coin)
			coin = null
			. = TRUE
		if("vend")
			if(!vend_ready)
				to_chat(usr, "<span class='warning'>The vending machine is busy!</span>")
				return
			if(panel_open)
				to_chat(usr, "<span class='warning'>The vending machine cannot dispense products while its service panel is open!</span>")
				return
			var/key = text2num(params["inum"])
			var/list/display_records = product_records + coin_records
			if(extended_inventory)
				display_records = product_records + coin_records + hidden_records
			if(key < 1 || key > length(display_records))
				to_chat(usr, "<span class='warning'>ERROR: invalid inum passed to vendor. Report this bug.</span>")
				return
			var/datum/data/vending_product/R = display_records[key]
			if(!istype(R))
				to_chat(usr, "<span class='warning'>ERROR: unknown vending_product record. Report this bug.</span>")
				return
			var/list/record_to_check = product_records + coin_records
			if(extended_inventory)
				record_to_check = product_records + coin_records + hidden_records
			if(!R || !istype(R) || !R.product_path)
				to_chat(usr, "<span class='warning'>ERROR: unknown product record. Report this bug.</span>")
				return
			if(R in hidden_records)
				if(!extended_inventory)
					// Exploit prevention, stop the user purchasing hidden stuff if they haven't hacked the machine.
					to_chat(usr, "<span class='warning'>ERROR: machine does not allow extended_inventory in current state. Report this bug.</span>")
					return
			else if (!(R in record_to_check))
				// Exploit prevention, stop the user
				message_admins("Vending machine exploit attempted by [ADMIN_LOOKUPFLW(usr)]!")
				return
			if (R.amount <= 0)
				to_chat(usr, "Sold out of [R.name].")
				flick(icon_deny, src)
				return

			vend_ready = FALSE // From this point onwards, vendor is locked to performing this transaction only, until it is resolved.

			if(!ishuman(usr) || R.price <= 0)
				// Either the purchaser is not human, or the item is free.
				// Skip all payment logic.
				vend(R, usr)
				add_fingerprint(usr)
				vend_ready = TRUE
				. = TRUE
				return

			// --- THE REST OF THIS PROC IS JUST PAYMENT LOGIC ---

			var/mob/living/carbon/human/H = usr
			var/obj/item/card/id/C = H.get_idcard(TRUE)

			if(!GLOB.vendor_account || GLOB.vendor_account.suspended)
				to_chat(usr, "Vendor account offline. Unable to process transaction.")
				flick(icon_deny, src)
				vend_ready = TRUE
				return

			currently_vending = R
			var/paid = FALSE

			if(istype(usr.get_active_hand(), /obj/item/stack/spacecash))
				var/obj/item/stack/spacecash/S = usr.get_active_hand()
				paid = pay_with_cash(S)
			else if(istype(C, /obj/item/card))
				// Because this uses H.get_idcard(TRUE), it will attempt to use:
				// active hand, inactive hand, pda.id, and then wear_id ID in that order
				// this is important because it lets people buy stuff with someone else's ID by holding it while using the vendor
				paid = pay_with_card(C, usr)
			else if(usr.can_advanced_admin_interact())
				to_chat(usr, "<span class='notice'>Vending object due to admin interaction.</span>")
				paid = TRUE
			else
				to_chat(usr, "<span class='warning'>Payment failure: you have no ID or other method of payment.")
				vend_ready = TRUE
				flick(icon_deny, src)
				. = TRUE // we set this because they shouldn't even be able to get this far, and we want the UI to update.
				return
			if(paid)
				vend(currently_vending, usr)
				. = TRUE
			else
				to_chat(usr, "<span class='warning'>Payment failure: unable to process payment.")
				vend_ready = TRUE
	if(.)
		add_fingerprint(usr)


/obj/machinery/vending/proc/vend(datum/data/vending_product/R, mob/user)
	if(!allowed(user) && !user.can_admin_interact() && !emagged && scan_id)	//For SECURE VENDING MACHINES YEAH
		to_chat(user, "<span class='warning'>Access denied.</span>")//Unless emagged of course
		flick(icon_deny, src)
		vend_ready = TRUE
		return

	if(!R.amount)
		to_chat(user, "<span class='warning'>The vending machine has ran out of that product.</span>")
		vend_ready = TRUE
		return

	vend_ready = FALSE //One thing at a time!!

	if(coin_records.Find(R))
		if(!coin)
			to_chat(user, "<span class='notice'>You need to insert a coin to get this item.</span>")
			vend_ready = TRUE
			return
		if(coin.string_attached)
			if(prob(50))
				to_chat(user, "<span class='notice'>You successfully pull the coin out before [src] could swallow it.</span>")
			else
				to_chat(user, "<span class='notice'>You weren't able to pull the coin out fast enough, the machine ate it, string and all.</span>")
				QDEL_NULL(coin)
		else
			QDEL_NULL(coin)

	R.amount--

	if(((last_reply + (vend_delay + 200)) <= world.time) && vend_reply)
		speak(src.vend_reply)
		last_reply = world.time

	use_power(vend_power_usage)	//actuators and stuff
	if(icon_vend) //Show the vending animation if needed
		flick(icon_vend, src)
	playsound(get_turf(src), 'sound/machines/machine_vend.ogg', 50, TRUE)
	addtimer(CALLBACK(src, PROC_REF(delayed_vend), R, user), vend_delay)

/obj/machinery/vending/proc/delayed_vend(datum/data/vending_product/R, mob/user)
	do_vend(R, user)
	vend_ready = TRUE
	currently_vending = null

//override this proc to add handling for what to do with the vended product when you have a inserted item and remember to include a parent call for this generic handling
/obj/machinery/vending/proc/do_vend(datum/data/vending_product/R, mob/user)
	if(!item_slot || !inserted_item)
		var/put_on_turf = TRUE
		var/obj/vended = new R.product_path()
		if(user && iscarbon(user) && user.Adjacent(src))
			if(user.put_in_hands(vended))
				put_on_turf = FALSE
		if(put_on_turf)
			var/turf/T = get_turf(src)
			vended.forceMove(T)
		return TRUE
	return FALSE

/* Example override for do_vend proc:
/obj/machinery/vending/example/do_vend(datum/data/vending_product/R)
	if(..())
		return
	var/obj/item/vended = new R.product_path()
	if(inserted_item.force == initial(inserted_item.force)
		inserted_item.force += vended.force
	inserted_item.damtype = vended.damtype
	qdel(vended)
*/

/obj/machinery/vending/process()
	if(stat & (BROKEN|NOPOWER))
		return

	if(!active)
		return

	if(src.seconds_electrified > 0)
		src.seconds_electrified--

	//Pitch to the people!  Really sell it!
	if(((last_slogan + src.slogan_delay) <= world.time) && (LAZYLEN(slogan_list)) && (!shut_up) && prob(5))
		var/slogan = pick(src.slogan_list)
		speak(slogan)
		last_slogan = world.time

	if(shoot_inventory && prob(shoot_chance))
		throw_item()

/obj/machinery/vending/extinguish_light()
	set_light(0)
	underlays.Cut()

/obj/machinery/vending/proc/speak(message)
	if(stat & NOPOWER)
		return
	if(!message)
		return

	atom_say(message)

/obj/machinery/vending/power_change()
	if(powered())
		stat &= ~NOPOWER
	else
		stat |= NOPOWER
	if((stat & (BROKEN|NOPOWER)))
		set_light(0)
	else
		set_light(light_range_on, light_power_on)
	update_icon(UPDATE_OVERLAYS)

/obj/machinery/vending/obj_break(damage_flag)
	if(!(stat & BROKEN))
		stat |= BROKEN
		set_light(0)
		update_icon(UPDATE_OVERLAYS)

		var/dump_amount = 0
		var/found_anything = TRUE
		while (found_anything)
			found_anything = FALSE
			for(var/record in shuffle(product_records))
				var/datum/data/vending_product/R = record
				if(R.amount <= 0) //Try to use a record that actually has something to dump.
					continue
				var/dump_path = R.product_path
				if(!dump_path)
					continue
				R.amount--
				// busting open a vendor will destroy some of the contents
				if(found_anything && prob(80))
					continue

				var/obj/O = new dump_path(loc)
				step(O, pick(GLOB.alldirs))
				found_anything = TRUE
				dump_amount++
				if(dump_amount >= 16)
					return

//Somebody cut an important wire and now we're following a new definition of "pitch."
/obj/machinery/vending/proc/throw_item()
	var/obj/throw_item = null
	var/mob/living/target = locate() in view(7, src)
	if(!target)
		return 0

	for(var/datum/data/vending_product/R in product_records)
		if(R.amount <= 0) //Try to use a record that actually has something to dump.
			continue
		var/dump_path = R.product_path
		if(!dump_path)
			continue

		R.amount--
		throw_item = new dump_path(loc)
		break
	if(!throw_item)
		return
	throw_item.throw_at(target, 16, 3)
	visible_message("<span class='danger'>[src] launches [throw_item.name] at [target.name]!</span>")

/obj/machinery/vending/onTransitZ()
	return
/*
 * Vending machine types
 */

/*

/obj/machinery/vending/[vendors name here]   // --vending machine template   :)
	name = ""
	desc = ""
	icon = ''
	icon_state = ""
	vend_delay = 15
	products = list()
	contraband = list()
	premium = list()

*/

/obj/machinery/vending/assist
	products = list(	/obj/item/assembly/prox_sensor = 5,/obj/item/assembly/igniter = 3,/obj/item/assembly/signaler = 4,
						/obj/item/wirecutters = 1, /obj/item/cartridge/signal = 4)
	contraband = list(/obj/item/flashlight = 5,/obj/item/assembly/timer = 2, /obj/item/assembly/voice = 2, /obj/item/assembly/health = 2)
	ads_list = list("Only the finest!","Have some tools.","The most robust equipment.","The finest gear in space!")
	refill_canister = /obj/item/vending_refill/assist

/obj/machinery/vending/boozeomat
	name = "\improper Booze-O-Mat"
	desc = "A technological marvel, supposedly able to mix just the mixture you'd like to drink the moment you ask for one."
	icon_state = "boozeomat"        //////////////18 drink entities below, plus the glasses, in case someone wants to edit the number of bottles
	icon_deny = "boozeomat_deny"
	icon_lightmask = "smartfridge"
	icon_panel = "smartfridge"
	icon_broken = "smartfridge"
	products = list(/obj/item/reagent_containers/food/drinks/bottle/gin = 5,
					/obj/item/reagent_containers/food/drinks/bottle/whiskey = 5,
					/obj/item/reagent_containers/food/drinks/bottle/tequila = 5,
					/obj/item/reagent_containers/food/drinks/bottle/vodka = 5,
					/obj/item/reagent_containers/food/drinks/bottle/vermouth = 5,
					/obj/item/reagent_containers/food/drinks/bottle/rum = 5,
					/obj/item/reagent_containers/food/drinks/bottle/wine = 5,
					/obj/item/reagent_containers/food/drinks/bag/goonbag = 3,
					/obj/item/reagent_containers/food/drinks/bottle/cognac = 5,
					/obj/item/reagent_containers/food/drinks/bottle/kahlua = 5,
					/obj/item/reagent_containers/food/drinks/cans/beer = 6,
					/obj/item/reagent_containers/food/drinks/cans/ale = 6,
					/obj/item/reagent_containers/food/drinks/cans/synthanol = 15,
					/obj/item/reagent_containers/food/drinks/bottle/orangejuice = 4,
					/obj/item/reagent_containers/food/drinks/bottle/tomatojuice = 4,
					/obj/item/reagent_containers/food/drinks/bottle/limejuice = 4,
					/obj/item/reagent_containers/food/drinks/bottle/cream = 4,
					/obj/item/reagent_containers/food/drinks/cans/tonic = 8,
					/obj/item/reagent_containers/food/drinks/cans/cola = 8,
					/obj/item/reagent_containers/food/drinks/cans/sodawater = 15,
					/obj/item/reagent_containers/food/drinks/drinkingglass = 30,
					/obj/item/reagent_containers/food/drinks/drinkingglass/shotglass = 30,
					/obj/item/reagent_containers/food/drinks/ice = 9)
	contraband = list(/obj/item/reagent_containers/food/drinks/tea = 10,
					  /obj/item/reagent_containers/food/drinks/bottle/fernet = 5)
	vend_delay = 15
	slogan_list = list("I hope nobody asks me for a bloody cup o' tea...","Alcohol is humanity's friend. Would you abandon a friend?","Quite delighted to serve you!","Is nobody thirsty on this station?")
	ads_list = list("Drink up!","Booze is good for you!","Alcohol is humanity's best friend.","Quite delighted to serve you!","Care for a nice, cold beer?","Nothing cures you like booze!","Have a sip!","Have a drink!","Have a beer!","Beer is good for you!","Only the finest alcohol!","Best quality booze since 2053!","Award-winning wine!","Maximum alcohol!","Man loves beer.","A toast for progress!")
	refill_canister = /obj/item/vending_refill/boozeomat

/obj/machinery/vending/boozeomat/syndicate_access
	req_access = list(ACCESS_SYNDICATE)


/obj/machinery/vending/coffee
	name = "\improper Solar's Best Hot Drinks"
	desc = "A vending machine which dispenses hot drinks."
	ads_list = list("Have a drink!","Drink up!","It's good for you!","Would you like a hot joe?","I'd kill for some coffee!","The best beans in the galaxy.","Only the finest brew for you.","Mmmm. Nothing like a coffee.","I like coffee, don't you?","Coffee helps you work!","Try some tea.","We hope you like the best!","Try our new chocolate!","Admin conspiracies")
	icon_state = "coffee"
	icon_lightmask = "coffee"
	icon_vend = "coffee_vend"
	icon_panel = "screen_vendor"
	item_slot = TRUE
	vend_delay = 34
	products = list(/obj/item/reagent_containers/food/drinks/coffee = 25,/obj/item/reagent_containers/food/drinks/tea = 25,/obj/item/reagent_containers/food/drinks/h_chocolate = 25,
					/obj/item/reagent_containers/food/drinks/chocolate = 10, /obj/item/reagent_containers/food/drinks/chicken_soup = 10,/obj/item/reagent_containers/food/drinks/weightloss = 10,
					/obj/item/reagent_containers/food/drinks/mug = 15)
	contraband = list(/obj/item/reagent_containers/food/drinks/ice = 10)
	premium = list(/obj/item/reagent_containers/food/drinks/mug/novelty = 5)
	prices = list(/obj/item/reagent_containers/food/drinks/coffee = 25, /obj/item/reagent_containers/food/drinks/tea = 25, /obj/item/reagent_containers/food/drinks/h_chocolate = 25, /obj/item/reagent_containers/food/drinks/chocolate = 25,
				  /obj/item/reagent_containers/food/drinks/chicken_soup = 30,/obj/item/reagent_containers/food/drinks/weightloss = 50, /obj/item/reagent_containers/food/drinks/mug = 50)
	refill_canister = /obj/item/vending_refill/coffee

/obj/machinery/vending/coffee/free
	prices = list()

/obj/machinery/vending/coffee/item_slot_check(mob/user, obj/item/I)
	if(!(istype(I, /obj/item/reagent_containers/glass) || istype(I, /obj/item/reagent_containers/food/drinks)))
		return FALSE
	if(!..())
		return FALSE
	if(!I.is_open_container())
		to_chat(user, "<span class='warning'>You need to open [I] before inserting it.</span>")
		return FALSE
	return TRUE

/obj/machinery/vending/coffee/do_vend(datum/data/vending_product/R, mob/user)
	if(..())
		return
	var/obj/item/reagent_containers/food/drinks/vended = new R.product_path()

	if(istype(vended, /obj/item/reagent_containers/food/drinks/mug))
		var/put_on_turf = TRUE
		if(user && iscarbon(user) && user.Adjacent(src))
			if(user.put_in_hands(vended))
				put_on_turf = FALSE
		if(put_on_turf)
			var/turf/T = get_turf(src)
			vended.forceMove(T)
		return

	vended.reagents.trans_to(inserted_item, vended.reagents.total_volume)
	if(vended.reagents.total_volume)
		var/put_on_turf = TRUE
		if(user && iscarbon(user) && user.Adjacent(src))
			if(user.put_in_hands(vended))
				put_on_turf = FALSE
		if(put_on_turf)
			var/turf/T = get_turf(src)
			vended.forceMove(T)
	else
		qdel(vended)


/obj/machinery/vending/snack
	name = "\improper Getmore Chocolate Corp"
	desc = "A snack machine courtesy of the Getmore Chocolate Corporation, based out of Mars."
	slogan_list = list("Try our new nougat bar!","Twice the calories for half the price!")
	ads_list = list("The healthiest!","Award-winning chocolate bars!","Mmm! So good!","Oh my god it's so juicy!","Have a snack.","Snacks are good for you!","Have some more Getmore!","Best quality snacks straight from mars.","We love chocolate!","Try our new jerky!")
	icon_state = "snack"
	icon_lightmask = "nutri"
	icon_off = "nutri"
	icon_panel = "thin_vendor"
	products = list(/obj/item/reagent_containers/food/snacks/candy/candybar = 6,/obj/item/reagent_containers/food/drinks/dry_ramen = 6,/obj/item/reagent_containers/food/snacks/chips =6,
					/obj/item/reagent_containers/food/snacks/sosjerky = 6,/obj/item/reagent_containers/food/snacks/no_raisin = 6,/obj/item/reagent_containers/food/snacks/pistachios =6,
					/obj/item/reagent_containers/food/snacks/spacetwinkie = 6,/obj/item/reagent_containers/food/snacks/cheesiehonkers = 6,/obj/item/reagent_containers/food/snacks/tastybread = 6)
	premium = list(/obj/item/reagent_containers/food/snacks/stroopwafel = 2)
	contraband = list(/obj/item/reagent_containers/food/snacks/syndicake = 6)
	prices = list(/obj/item/reagent_containers/food/snacks/candy/candybar = 20,/obj/item/reagent_containers/food/drinks/dry_ramen = 30,
					/obj/item/reagent_containers/food/snacks/chips =25,/obj/item/reagent_containers/food/snacks/sosjerky = 30,/obj/item/reagent_containers/food/snacks/no_raisin = 20,
					/obj/item/reagent_containers/food/snacks/pistachios = 35, /obj/item/reagent_containers/food/snacks/spacetwinkie = 30,/obj/item/reagent_containers/food/snacks/cheesiehonkers = 25,/obj/item/reagent_containers/food/snacks/tastybread = 30)
	refill_canister = /obj/item/vending_refill/snack

/obj/machinery/vending/snack/free
	prices = list()

/obj/machinery/vending/chinese
	name = "\improper Mr. Chang"
	desc = "A self-serving Chinese food machine, for all your Chinese food needs."
	slogan_list = list("Taste 5000 years of culture!","Mr. Chang, approved for safe consumption in over 10 sectors!","Chinese food is great for a date night, or a lonely night!","You can't go wrong with Mr. Chang's authentic Chinese food!")
	icon_state = "chang"
	icon_lightmask = "chang"
	products = list(/obj/item/reagent_containers/food/snacks/chinese/chowmein = 6, /obj/item/reagent_containers/food/snacks/chinese/tao = 6, /obj/item/reagent_containers/food/snacks/chinese/sweetsourchickenball = 6, /obj/item/reagent_containers/food/snacks/chinese/newdles = 6,
					/obj/item/reagent_containers/food/snacks/chinese/rice = 6, /obj/item/reagent_containers/food/snacks/fortunecookie = 6)
	prices = list(/obj/item/reagent_containers/food/snacks/chinese/chowmein = 50, /obj/item/reagent_containers/food/snacks/chinese/tao = 50, /obj/item/reagent_containers/food/snacks/chinese/sweetsourchickenball = 50, /obj/item/reagent_containers/food/snacks/chinese/newdles = 50,
					/obj/item/reagent_containers/food/snacks/chinese/rice = 50, /obj/item/reagent_containers/food/snacks/fortunecookie = 50)
	refill_canister = /obj/item/vending_refill/chinese

/obj/machinery/vending/chinese/free
	prices = list()

/obj/machinery/vending/cola
	name = "\improper Robust Softdrinks"
	desc = "A soft drink vendor provided by Robust Industries, LLC."
	icon_state = "Cola_Machine"
	icon_lightmask = "Cola_Machine"
	icon_panel = "thin_vendor"
	slogan_list = list("Robust Softdrinks: More robust than a toolbox to the head!")
	ads_list = list("Refreshing!","Hope you're thirsty!","Over 1 million drinks sold!","Thirsty? Why not cola?","Please, have a drink!","Drink up!","The best drinks in space.")
	products = list(/obj/item/reagent_containers/food/drinks/cans/cola = 10,/obj/item/reagent_containers/food/drinks/cans/space_mountain_wind = 10,
					/obj/item/reagent_containers/food/drinks/cans/dr_gibb = 10,/obj/item/reagent_containers/food/drinks/cans/starkist = 10,
					/obj/item/reagent_containers/food/drinks/cans/space_up = 10,/obj/item/reagent_containers/food/drinks/cans/grape_juice = 10)
	contraband = list(/obj/item/reagent_containers/food/drinks/cans/thirteenloko = 5)
	prices = list(/obj/item/reagent_containers/food/drinks/cans/cola = 20,/obj/item/reagent_containers/food/drinks/cans/space_mountain_wind = 20,
					/obj/item/reagent_containers/food/drinks/cans/dr_gibb = 20,/obj/item/reagent_containers/food/drinks/cans/starkist = 20,
					/obj/item/reagent_containers/food/drinks/cans/space_up = 20,/obj/item/reagent_containers/food/drinks/cans/grape_juice = 20)
	refill_canister = /obj/item/vending_refill/cola

/obj/machinery/vending/cola/free
	prices = list()

/obj/machinery/vending/cart
	name = "\improper PTech"
	desc = "Cartridges for PDA's."
	slogan_list = list("Carts to go!")
	icon_state = "cart"
	icon_lightmask = "med"
	icon_deny = "cart_deny"
	icon_panel = "wide_vendor"
	products = list(/obj/item/pda =10,/obj/item/cartridge/mob_hunt_game = 25,/obj/item/cartridge/medical = 10,/obj/item/cartridge/chemistry = 10,
					/obj/item/cartridge/engineering = 10,/obj/item/cartridge/atmos = 10,/obj/item/cartridge/janitor = 10,
					/obj/item/cartridge/signal/toxins = 10,/obj/item/cartridge/signal = 10)
	contraband = list(/obj/item/cartridge/clown = 1,/obj/item/cartridge/mime = 1)
	prices = list(/obj/item/pda =300,/obj/item/cartridge/mob_hunt_game = 50,/obj/item/cartridge/medical = 200,/obj/item/cartridge/chemistry = 150,/obj/item/cartridge/engineering = 100,
					/obj/item/cartridge/atmos = 75,/obj/item/cartridge/janitor = 100,/obj/item/cartridge/signal/toxins = 150,
					/obj/item/cartridge/signal = 75)
	refill_canister = /obj/item/vending_refill/cart

/obj/machinery/vending/cart/free
	prices = list()

/obj/machinery/vending/liberationstation
	name = "\improper Liberation Station"
	desc = "An overwhelming amount of <b>ancient patriotism</b> washes over you just by looking at the machine."
	icon_state = "liberationstation"
	icon_lightmask = "liberationstation"
	req_access_txt = "1"
	slogan_list = list("Liberation Station: Your one-stop shop for all things second amendment!","Be a patriot today, pick up a gun!","Quality weapons for cheap prices!","Better dead than red!")
	ads_list = list("Float like an astronaut, sting like a bullet!","Express your second amendment today!","Guns don't kill people, but you can!","Who needs responsibilities when you have guns?")
	vend_reply = "Remember the name: Liberation Station!"
	products = list(/obj/item/gun/projectile/automatic/pistol/deagle/gold = 2,/obj/item/gun/projectile/automatic/pistol/deagle/camo = 2,
					/obj/item/gun/projectile/automatic/pistol/m1911 = 2,/obj/item/gun/projectile/automatic/proto = 2,
					/obj/item/gun/projectile/shotgun/automatic/combat = 2,/obj/item/gun/projectile/automatic/gyropistol = 1,
					/obj/item/gun/projectile/shotgun = 2,/obj/item/gun/projectile/automatic/ar = 2)
	premium = list(/obj/item/ammo_box/magazine/smgm9mm = 2,/obj/item/ammo_box/magazine/m50 = 4,/obj/item/ammo_box/magazine/m45 = 2,/obj/item/ammo_box/magazine/m75 = 2)
	contraband = list(/obj/item/clothing/under/costume/patriotsuit = 1,/obj/item/bedsheet/patriot = 3)
	armor = list(melee = 100, bullet = 100, laser = 100, energy = 100, bomb = 0, bio = 0, rad = 0, fire = 100, acid = 50)
	resistance_flags = FIRE_PROOF

/obj/machinery/vending/toyliberationstation
	name = "\improper Syndicate Donksoft Toy Vendor"
	desc = "An ages 8 and up approved vendor that dispenses toys. If you were to find the right wires, you can unlock the adult mode setting!"
	icon_state = "syndi"
	icon_lightmask = "syndi"
	slogan_list = list("Get your cool toys today!","Trigger a valid hunter today!","Quality toy weapons for cheap prices!","Give them to HoPs for all access!","Give them to HoS to get permabrigged!")
	ads_list = list("Feel robust with your toys!","Express your inner child today!","Toy weapons don't kill people, but valid hunters do!","Who needs responsibilities when you have toy weapons?","Make your next murder FUN!")
	vend_reply = "Come back for more!"
	products = list(/obj/item/gun/projectile/automatic/toy = 10,
					/obj/item/gun/projectile/automatic/toy/pistol= 10,
					/obj/item/gun/projectile/shotgun/toy = 10,
					/obj/item/toy/sword = 10,
					/obj/item/ammo_box/foambox = 20,
					/obj/item/toy/foamblade = 10,
					/obj/item/toy/syndicateballoon = 10,
					/obj/item/clothing/suit/syndicatefake = 5,
					/obj/item/clothing/head/syndicatefake = 5) //OPS IN DORMS oh wait it's just an assistant
	contraband = list(/obj/item/gun/projectile/shotgun/toy/crossbow= 10,   //Congrats, you unlocked the +18 setting!
					  /obj/item/gun/projectile/automatic/c20r/toy/riot = 10,
					  /obj/item/gun/projectile/automatic/l6_saw/toy/riot = 10,
  					  /obj/item/gun/projectile/automatic/sniper_rifle/toy = 10,
					  /obj/item/ammo_box/foambox/riot = 20,
					  /obj/item/toy/katana = 10,
					  /obj/item/twohanded/dualsaber/toy = 5,
					  /obj/item/deck/cards/syndicate = 10) //Gambling and it hurts, making it a +18 item
	armor = list(melee = 100, bullet = 100, laser = 100, energy = 100, bomb = 0, bio = 0, rad = 0, fire = 100, acid = 50)
	resistance_flags = FIRE_PROOF

/obj/machinery/vending/cigarette
	name = "\improper ShadyCigs Deluxe"
	desc = "If you want to get cancer, might as well do it in style."
	slogan_list = list("Space cigs taste good like a cigarette should.","I'd rather toolbox than switch.","Smoke!","Don't believe the reports - smoke today!")
	ads_list = list("Probably not bad for you!","Don't believe the scientists!","It's good for you!","Don't quit, buy more!","Smoke!","Nicotine heaven.","Best cigarettes since 2150.","Award-winning cigs.")
	vend_delay = 34
	icon_state = "cigs"
	icon_lightmask = "cigs"
	products = list(
		/obj/item/storage/fancy/cigarettes/cigpack_robust = 12,
		/obj/item/storage/fancy/cigarettes/cigpack_uplift = 6,
		/obj/item/storage/fancy/cigarettes/cigpack_midori = 6,
		/obj/item/storage/fancy/cigarettes/cigpack_random = 6,
		/obj/item/reagent_containers/food/pill/patch/nicotine = 10,
		/obj/item/storage/box/matches = 10,
		/obj/item/lighter/random = 4,
		/obj/item/storage/fancy/rollingpapers = 5)
	contraband = list(/obj/item/lighter/zippo = 4)
	premium = list(/obj/item/clothing/mask/cigarette/cigar/havana = 2,
		/obj/item/storage/fancy/cigarettes/cigpack_robustgold = 1)
	prices = list(/obj/item/storage/fancy/cigarettes/cigpack_robust = 60,
		/obj/item/storage/fancy/cigarettes/cigpack_uplift = 80,
		/obj/item/storage/fancy/cigarettes/cigpack_midori = 100,
		/obj/item/storage/fancy/cigarettes/cigpack_random = 120,
		/obj/item/reagent_containers/food/pill/patch/nicotine = 70,
		/obj/item/storage/box/matches = 10,
		/obj/item/lighter/random = 60,
		/obj/item/storage/fancy/rollingpapers = 20)
	refill_canister = /obj/item/vending_refill/cigarette

/obj/machinery/vending/cigarette/free
	prices = list()

/obj/machinery/vending/cigarette/syndicate
	products = list(/obj/item/storage/fancy/cigarettes/cigpack_syndicate = 7,
					/obj/item/storage/fancy/cigarettes/cigpack_uplift = 3,
					/obj/item/storage/fancy/cigarettes/cigpack_robust = 2,
					/obj/item/storage/fancy/cigarettes/cigpack_carp = 3,
					/obj/item/storage/fancy/cigarettes/cigpack_midori = 1,
					/obj/item/storage/box/matches = 10,
					/obj/item/lighter/zippo = 4,
					/obj/item/storage/fancy/rollingpapers = 5)

/obj/machinery/vending/cigarette/syndicate/free
	prices = list()

/obj/machinery/vending/cigarette/beach //Used in the lavaland_biodome_beach.dmm ruin
	name = "\improper ShadyCigs Ultra"
	desc = "Now with extra premium products!"
	ads_list = list("Probably not bad for you!","Dope will get you through times of no money better than money will get you through times of no dope!","It's good for you!")
	slogan_list = list("Turn on, tune in, drop out!","Better living through chemistry!","Toke!","Don't forget to keep a smile on your lips and a song in your heart!")
	products = list(/obj/item/storage/fancy/cigarettes = 5,
					/obj/item/storage/fancy/cigarettes/cigpack_uplift = 3,
					/obj/item/storage/fancy/cigarettes/cigpack_robust = 3,
					/obj/item/storage/fancy/cigarettes/cigpack_carp = 3,
					/obj/item/storage/fancy/cigarettes/cigpack_midori = 3,
					/obj/item/storage/box/matches = 10,
					/obj/item/lighter/random = 4,
					/obj/item/storage/fancy/rollingpapers = 5)
	premium = list(/obj/item/clothing/mask/cigarette/cigar/havana = 2,
				   /obj/item/storage/fancy/cigarettes/cigpack_robustgold = 1,
				   /obj/item/lighter/zippo = 3)
	prices = list()

/obj/machinery/vending/medical
	name = "\improper NanoMed Plus"
	desc = "Medical drug dispenser."
	icon_state = "med"
	icon_lightmask = "med"
	icon_deny = "med_deny"
	icon_panel = "wide_vendor"
	ads_list = list("Go save some lives!","The best stuff for your medbay.","Only the finest tools.","Natural chemicals!","This stuff saves lives.","Don't you want some?","Ping!")
	req_access_txt = "5"
	products = list(/obj/item/reagent_containers/syringe = 12,
					/obj/item/reagent_containers/food/pill/patch/styptic = 4,
					/obj/item/reagent_containers/food/pill/patch/silver_sulf = 4,
					/obj/item/reagent_containers/applicator/brute = 3,
					/obj/item/reagent_containers/applicator/burn = 3,
					/obj/item/reagent_containers/glass/bottle/charcoal = 4,
					/obj/item/reagent_containers/glass/bottle/epinephrine = 4,
					/obj/item/reagent_containers/glass/bottle/salicylic = 4,
					/obj/item/reagent_containers/glass/bottle/potassium_iodide = 3,
					/obj/item/reagent_containers/glass/bottle/saline = 5,
					/obj/item/reagent_containers/glass/bottle/morphine = 4,
					/obj/item/reagent_containers/glass/bottle/atropine = 3,
					/obj/item/reagent_containers/glass/bottle/oculine = 2,
					/obj/item/reagent_containers/syringe/antiviral = 6,
					/obj/item/reagent_containers/syringe/calomel = 10,
					/obj/item/reagent_containers/syringe/heparin = 4,
					/obj/item/reagent_containers/hypospray/autoinjector = 5,
					/obj/item/reagent_containers/food/pill/salbutamol = 10,
					/obj/item/reagent_containers/food/pill/mannitol = 10,
					/obj/item/reagent_containers/food/pill/mutadone = 5,
					/obj/item/stack/medical/bruise_pack/advanced = 4,
					/obj/item/stack/medical/ointment/advanced = 4,
					/obj/item/stack/medical/bruise_pack = 4,
					/obj/item/stack/medical/splint = 4,
					/obj/item/reagent_containers/glass/beaker = 4,
					/obj/item/reagent_containers/dropper = 4,
					/obj/item/healthanalyzer/advanced = 4,
					/obj/item/reagent_containers/hypospray/safety = 2,
					/obj/item/sensor_device = 2,
					/obj/item/pinpointer/crew = 2)
	contraband = list(/obj/item/reagent_containers/syringe/insulin = 6,
					/obj/item/reagent_containers/glass/bottle/sulfonal = 1,
					/obj/item/reagent_containers/glass/bottle/pancuronium = 1)
	armor = list(melee = 50, bullet = 20, laser = 20, energy = 20, bomb = 0, bio = 0, rad = 0, fire = 100, acid = 70)
	resistance_flags = FIRE_PROOF
	refill_canister = /obj/item/vending_refill/medical

/obj/machinery/vending/medical/syndicate_access
	name = "\improper SyndiMed Plus"
	req_access = list(ACCESS_SYNDICATE)

/obj/machinery/vending/plasmaresearch
	name = "\improper Toximate 3000"
	desc = "All the fine parts you need in one vending machine!"
	products = list(/obj/item/assembly/prox_sensor = 8, /obj/item/assembly/igniter = 8, /obj/item/assembly/signaler = 8,
					/obj/item/wirecutters = 1, /obj/item/assembly/timer = 8)
	contraband = list(/obj/item/flashlight = 5, /obj/item/assembly/voice = 3, /obj/item/assembly/health = 3, /obj/item/assembly/infra = 3)

/obj/machinery/vending/wallmed
	name = "\improper NanoMed"
	desc = "Wall-mounted Medical Equipment dispenser."
	ads_list = list("Go save some lives!","The best stuff for your medbay.","Only the finest tools.","Natural chemicals!","This stuff saves lives.","Don't you want some?")
	icon_state = "wallmed"
	icon_deny = "wallmed_deny"
	icon_lightmask = "wallmed"
	icon_panel = "wallmed"
	icon_broken = "wallmed"
	density = FALSE //It is wall-mounted, and thus, not dense. --Superxpdude
	products = list(/obj/item/stack/medical/bruise_pack = 2, /obj/item/stack/medical/ointment = 2, /obj/item/reagent_containers/hypospray/autoinjector = 4, /obj/item/healthanalyzer = 1)
	contraband = list(/obj/item/reagent_containers/syringe/charcoal = 4, /obj/item/reagent_containers/syringe/antiviral = 4, /obj/item/reagent_containers/food/pill/tox = 1)
	armor = list(melee = 50, bullet = 20, laser = 20, energy = 20, bomb = 0, bio = 0, rad = 0, fire = 100, acid = 70)
	resistance_flags = FIRE_PROOF
	refill_canister = /obj/item/vending_refill/wallmed


/obj/machinery/vending/wallmed/syndicate
	name = "\improper SyndiMed Plus"
	desc = "<b>EVIL</b> wall-mounted Medical Equipment dispenser."
	icon_state = "syndimed"
	icon_deny = "syndimed_deny"
	ads_list = list("Go end some lives!","The best stuff for your ship.","Only the finest tools.","Natural chemicals!","This stuff saves lives.","Don't you want some?","Ping!")
	req_access_txt = "150"
	products = list(/obj/item/stack/medical/bruise_pack = 2,/obj/item/stack/medical/ointment = 2,/obj/item/reagent_containers/hypospray/autoinjector = 4,/obj/item/healthanalyzer = 1)
	contraband = list(/obj/item/reagent_containers/syringe/charcoal = 4,/obj/item/reagent_containers/syringe/antiviral = 4,/obj/item/reagent_containers/food/pill/tox = 1)

/obj/machinery/vending/security
	name = "\improper SecTech"
	desc = "A security equipment vendor."
	ads_list = list("Crack capitalist skulls!","Beat some heads in!","Don't forget - harm is good!","Your weapons are right here.","Handcuffs!","Freeze, scumbag!","Don't tase me bro!","Tase them, bro.","Why not have a donut?")
	icon_state = "sec"
	icon_lightmask = "sec"
	icon_deny = "sec_deny"
	icon_panel = "wide_vendor"
	req_access_txt = "1"
	products = list(/obj/item/restraints/handcuffs = 8,/obj/item/restraints/handcuffs/cable/zipties = 8,/obj/item/grenade/flashbang = 4,/obj/item/flash = 5,
					/obj/item/reagent_containers/food/snacks/donut = 12,/obj/item/storage/box/evidence = 6,/obj/item/flashlight/seclite = 4,/obj/item/restraints/legcuffs/bola/energy = 7,
					/obj/item/clothing/mask/muzzle/safety = 4)
	contraband = list(/obj/item/clothing/glasses/sunglasses = 2,/obj/item/storage/fancy/donut_box = 2,/obj/item/hailer = 5)
	refill_canister = /obj/item/vending_refill/security

/obj/machinery/vending/hydronutrients
	name = "\improper NutriMax"
	desc = "A plant nutrients vendor"
	slogan_list = list("Aren't you glad you don't have to fertilize the natural way?","Now with 50% less stink!","Plants are people too!")
	ads_list = list("We like plants!","Don't you want some?","The greenest thumbs ever.","We like big plants.","Soft soil...")
	icon_state = "nutri"
	icon_deny = "nutri_deny"
	icon_lightmask = "nutri"
	icon_panel = "thin_vendor"
	products = list(/obj/item/reagent_containers/glass/bottle/nutrient/ez = 20,/obj/item/reagent_containers/glass/bottle/nutrient/l4z = 13,/obj/item/reagent_containers/glass/bottle/nutrient/rh = 6,/obj/item/reagent_containers/spray/pestspray = 20,
					/obj/item/reagent_containers/syringe = 5,/obj/item/storage/bag/plants = 5,/obj/item/cultivator = 3,/obj/item/shovel/spade = 3,/obj/item/plant_analyzer = 4)
	contraband = list(/obj/item/reagent_containers/glass/bottle/ammonia = 10,/obj/item/reagent_containers/glass/bottle/diethylamine = 5)
	refill_canister = /obj/item/vending_refill/hydronutrients

/obj/machinery/vending/hydronutrients/syndicate_druglab
	products = list(/obj/item/reagent_containers/glass/bottle/nutrient/ez = 12,
					/obj/item/reagent_containers/glass/bottle/nutrient/l4z = 2,
					/obj/item/reagent_containers/glass/bottle/nutrient/rh = 3,
					/obj/item/reagent_containers/spray/pestspray = 7,
					/obj/item/reagent_containers/syringe = 11,
					/obj/item/storage/bag/plants = 2,
					/obj/item/cultivator = 3,
					/obj/item/shovel/spade = 2,
					/obj/item/plant_analyzer = 2,
					/obj/item/reagent_containers/glass/bottle/ammonia = 6,
					/obj/item/reagent_containers/glass/bottle/diethylamine = 8)
	contraband = list()

/obj/machinery/vending/hydroseeds
	name = "\improper MegaSeed Servitor"
	desc = "When you need seeds fast!"
	slogan_list = list("THIS'S WHERE TH' SEEDS LIVE! GIT YOU SOME!","Hands down the best seed selection on the station!","Also certain mushroom varieties available, more for experts! Get certified today!")
	ads_list = list("We like plants!","Grow some crops!","Grow, baby, growww!","Aw h'yeah son!")
	icon_state = "seeds"
	icon_lightmask = "seeds"
	icon_panel = "thin_vendor"
	products = list(/obj/item/seeds/aloe =3,
					/obj/item/seeds/ambrosia = 3,
					/obj/item/seeds/apple = 3,
					/obj/item/seeds/banana = 3,
					/obj/item/seeds/berry = 3,
					/obj/item/seeds/cabbage = 3,
					/obj/item/seeds/carrot = 3,
					/obj/item/seeds/cherry = 3,
					/obj/item/seeds/chanter = 3,
					/obj/item/seeds/chili = 3,
					/obj/item/seeds/cocoapod = 3,
					/obj/item/seeds/coffee = 3,
					/obj/item/seeds/comfrey =3,
					/obj/item/seeds/corn = 3,
					/obj/item/seeds/cotton = 3,
					/obj/item/seeds/nymph =3,
					/obj/item/seeds/eggplant = 3,
					/obj/item/seeds/garlic = 3,
					/obj/item/seeds/grape = 3,
					/obj/item/seeds/grass = 3,
					/obj/item/seeds/lemon = 3,
					/obj/item/seeds/lime = 3,
					/obj/item/seeds/mint = 3,
					/obj/item/seeds/onion = 3,
					/obj/item/seeds/orange = 3,
					/obj/item/seeds/peanuts = 3,
					/obj/item/seeds/pineapple = 3,
					/obj/item/seeds/poppy = 3,
					/obj/item/seeds/potato = 3,
					/obj/item/seeds/pumpkin = 3,
					/obj/item/seeds/replicapod = 3,
					/obj/item/seeds/wheat/rice = 3,
					/obj/item/seeds/soya = 3,
					/obj/item/seeds/sugarcane = 3,
					/obj/item/seeds/sunflower = 3,
					/obj/item/seeds/tea = 3,
					/obj/item/seeds/tobacco = 3,
					/obj/item/seeds/tomato = 3,
					/obj/item/seeds/tower = 3,
					/obj/item/seeds/watermelon = 3,
					/obj/item/seeds/wheat = 3,
					/obj/item/seeds/whitebeet = 3)
	contraband = list(/obj/item/seeds/cannabis = 3,
					  /obj/item/seeds/amanita = 2,
					  /obj/item/seeds/fungus = 3,
					  /obj/item/seeds/glowshroom = 2,
					  /obj/item/seeds/liberty = 2,
					  /obj/item/seeds/nettle = 2,
					  /obj/item/seeds/plump = 2,
					  /obj/item/seeds/reishi = 2,
					  /obj/item/seeds/starthistle = 2,
					  /obj/item/seeds/random = 2)
	premium = list(/obj/item/reagent_containers/spray/waterflower = 1)
	refill_canister = /obj/item/vending_refill/hydroseeds

/obj/machinery/vending/hydroseeds/syndicate_druglab
	products = list(/obj/item/seeds/ambrosia/deus = 2,
					/obj/item/seeds/cannabis = 2,
					/obj/item/seeds/coffee = 3,
					/obj/item/seeds/liberty = 2,
					/obj/item/seeds/cannabis/rainbow = 1,
					/obj/item/seeds/reishi = 2,
					/obj/item/seeds/tobacco = 1)
	contraband = list()
	premium = list()
	refill_canister = null

/obj/machinery/vending/magivend
	name = "\improper MagiVend"
	desc = "A magic vending machine."
	icon_state = "MagiVend"
	slogan_list = list("Sling spells the proper way with MagiVend!","Be your own Houdini! Use MagiVend!")
	vend_delay = 15
	vend_reply = "Have an enchanted evening!"
	ads_list = list("FJKLFJSD","AJKFLBJAKL","1234 LOONIES LOL!",">MFW","Kill them fuckers!","GET DAT FUKKEN DISK","HONK!","EI NATH","Destroy the station!","Admin conspiracies since forever!","Space-time bending hardware!")
	products = list(/obj/item/clothing/head/wizard = 1,
					/obj/item/clothing/suit/wizrobe = 1,
					/obj/item/clothing/head/wizard/red = 1,
					/obj/item/clothing/suit/wizrobe/red = 1,
					/obj/item/clothing/shoes/sandal = 1,
					/obj/item/clothing/suit/wizrobe/clown = 1,
					/obj/item/clothing/head/wizard/clown = 1,
					/obj/item/clothing/mask/gas/clownwiz = 1,
					/obj/item/clothing/shoes/clown_shoes/magical = 1,
					/obj/item/clothing/suit/wizrobe/mime = 1,
					/obj/item/clothing/head/wizard/mime = 1,
					/obj/item/clothing/mask/gas/mime/wizard = 1,
					/obj/item/clothing/shoes/sandal/marisa = 1,
					/obj/item/twohanded/staff = 2)
	contraband = list(/obj/item/reagent_containers/glass/bottle/wizarditis = 1)
	armor = list(melee = 100, bullet = 100, laser = 100, energy = 100, bomb = 0, bio = 0, rad = 0, fire = 100, acid = 50)
	resistance_flags = FIRE_PROOF

/obj/machinery/vending/autodrobe
	name = "\improper AutoDrobe"
	desc = "A vending machine for costumes."
	icon_state = "theater"
	icon_lightmask = "theater"
	icon_deny = "theater_deny"
	slogan_list = list("Dress for success!","Suited and booted!","It's show time!","Why leave style up to fate? Use AutoDrobe!")
	vend_delay = 15
	vend_reply = "Thank you for using AutoDrobe!"
	products = list(/obj/item/clothing/suit/chickensuit = 1,
					/obj/item/clothing/head/chicken = 1,
					/obj/item/clothing/under/costume/gladiator = 1,
					/obj/item/clothing/head/helmet/gladiator = 1,
					/obj/item/clothing/under/misc/gimmick/rank/captain/suit = 1,
					/obj/item/clothing/head/flatcap = 1,
					/obj/item/clothing/suit/storage/labcoat/mad = 1,
					/obj/item/clothing/glasses/gglasses = 1,
					/obj/item/clothing/shoes/jackboots = 1,
					/obj/item/clothing/under/dress/schoolgirl = 1,
					/obj/item/clothing/under/dress/blackskirt = 1,
					/obj/item/clothing/suit/toggle/owlwings = 1,
					/obj/item/clothing/under/costume/owl = 1,
					/obj/item/clothing/mask/gas/owl_mask = 1,
					/obj/item/clothing/suit/toggle/owlwings/griffinwings = 1,
					/obj/item/clothing/under/costume/griffin = 1,
					/obj/item/clothing/shoes/griffin = 1,
					/obj/item/clothing/head/griffin = 1,
					/obj/item/clothing/accessory/waistcoat = 1,
					/obj/item/clothing/under/suit/black = 1,
					/obj/item/clothing/head/that =1,
					/obj/item/clothing/under/costume/kilt = 1,
					/obj/item/clothing/accessory/waistcoat = 1,
					/obj/item/clothing/glasses/monocle =1,
					/obj/item/clothing/head/bowlerhat = 1,
					/obj/item/cane = 1,
					/obj/item/clothing/under/misc/sl_suit = 1,
					/obj/item/clothing/mask/fakemoustache = 1,
					/obj/item/clothing/suit/bio_suit/plaguedoctorsuit = 1,
					/obj/item/clothing/head/plaguedoctorhat = 1,
					/obj/item/clothing/mask/gas/plaguedoctor = 1,
					/obj/item/clothing/suit/apron = 1,
					/obj/item/clothing/under/misc/waiter = 1,
					/obj/item/clothing/suit/jacket/miljacket = 1,
					/obj/item/clothing/suit/jacket/miljacket/white = 1,
					/obj/item/clothing/suit/jacket/miljacket/desert = 1,
					/obj/item/clothing/suit/jacket/miljacket/navy = 1,
					/obj/item/clothing/under/costume/pirate = 1,
					/obj/item/clothing/suit/pirate_brown = 1,
					/obj/item/clothing/suit/pirate_black =1,
					/obj/item/clothing/under/costume/pirate_rags =1,
					/obj/item/clothing/head/pirate = 1,
					/obj/item/clothing/head/bandana = 1,
					/obj/item/clothing/head/bandana = 1,
					/obj/item/clothing/under/costume/soviet = 1,
					/obj/item/clothing/head/ushanka = 1,
					/obj/item/clothing/suit/imperium_monk = 1,
					/obj/item/clothing/mask/gas/cyborg = 1,
					/obj/item/clothing/suit/holidaypriest = 1,
					/obj/item/clothing/head/wizard/marisa/fake = 1,
					/obj/item/clothing/suit/wizrobe/marisa/fake = 1,
					/obj/item/clothing/under/dress/sundress = 1,
					/obj/item/clothing/head/witchwig = 1,
					/obj/item/twohanded/staff/broom = 1,
					/obj/item/clothing/suit/wizrobe/fake = 1,
					/obj/item/clothing/head/wizard/fake = 1,
					/obj/item/twohanded/staff = 3,
					/obj/item/clothing/mask/gas/clown_hat/sexy = 1,
					/obj/item/clothing/under/rank/civilian/clown/sexy = 1,
					/obj/item/clothing/mask/gas/sexymime = 1,
					/obj/item/clothing/under/rank/civilian/mime/sexy = 1,
					/obj/item/clothing/mask/face/bat = 1,
					/obj/item/clothing/mask/face/bee = 1,
					/obj/item/clothing/mask/face/bear = 1,
					/obj/item/clothing/mask/face/raven = 1,
					/obj/item/clothing/mask/face/jackal = 1,
					/obj/item/clothing/mask/face/fox = 1,
					/obj/item/clothing/mask/face/tribal = 1,
					/obj/item/clothing/mask/face/rat = 1,
					/obj/item/clothing/suit/apron/overalls = 1,
					/obj/item/clothing/head/rabbitears =1,
					/obj/item/clothing/head/sombrero = 1,
					/obj/item/clothing/suit/poncho = 1,
					/obj/item/clothing/suit/poncho/green = 1,
					/obj/item/clothing/suit/poncho/red = 1,
					/obj/item/clothing/accessory/blue = 1,
					/obj/item/clothing/accessory/red = 1,
					/obj/item/clothing/accessory/black = 1,
					/obj/item/clothing/accessory/horrible = 1,
					/obj/item/clothing/under/costume/maid = 1,
					/obj/item/clothing/under/costume/janimaid = 1,
					/obj/item/clothing/under/costume/jester = 1,
					/obj/item/clothing/head/jester = 1,
					/obj/item/clothing/under/pants/camo = 1,
					/obj/item/clothing/mask/bandana = 1,
					/obj/item/clothing/mask/bandana/black = 1,
					/obj/item/clothing/shoes/singery = 1,
					/obj/item/clothing/under/costume/singery = 1,
					/obj/item/clothing/shoes/singerb = 1,
					/obj/item/clothing/under/costume/singerb = 1,
					/obj/item/clothing/suit/hooded/carp_costume = 1,
					/obj/item/clothing/suit/hooded/bee_costume = 1,
					/obj/item/clothing/suit/snowman = 1,
					/obj/item/clothing/head/snowman = 1,
					/obj/item/clothing/head/cueball = 1,
					/obj/item/clothing/under/misc/scratch = 1,
					/obj/item/clothing/under/dress/victdress = 1,
					/obj/item/clothing/under/dress/victdress/red = 1,
					/obj/item/clothing/suit/victcoat = 1,
					/obj/item/clothing/suit/victcoat/red = 1,
					/obj/item/clothing/under/suit/victsuit = 1,
					/obj/item/clothing/under/suit/victsuit/redblk = 1,
					/obj/item/clothing/under/suit/victsuit/red = 1,
					/obj/item/clothing/suit/tailcoat = 1,
					/obj/item/clothing/under/costume/tourist_suit = 1,
					/obj/item/clothing/suit/draculacoat = 1,
					/obj/item/clothing/head/zepelli = 1,
					/obj/item/clothing/under/misc/redhawaiianshirt = 1,
					/obj/item/clothing/under/misc/pinkhawaiianshirt = 1,
					/obj/item/clothing/under/misc/bluehawaiianshirt = 1,
					/obj/item/clothing/under/misc/orangehawaiianshirt = 1)
	contraband = list(/obj/item/clothing/suit/judgerobe = 1,
					  /obj/item/clothing/head/powdered_wig = 1,
					  /obj/item/gun/magic/wand = 1,
					  /obj/item/clothing/mask/balaclava=1,
					  /obj/item/clothing/mask/horsehead = 2)
	premium = list(/obj/item/clothing/suit/hgpirate = 1,
				   /obj/item/clothing/head/hgpiratecap = 1,
				   /obj/item/clothing/head/helmet/roman/fake = 1,
				   /obj/item/clothing/head/helmet/roman/legionaire/fake = 1,
				   /obj/item/clothing/under/costume/roman = 1,
				   /obj/item/clothing/shoes/roman = 1,
				   /obj/item/shield/riot/roman/fake = 1,
				   /obj/item/clothing/under/costume/cuban_suit = 1,
				   /obj/item/clothing/head/cuban_hat = 1)
	refill_canister = /obj/item/vending_refill/autodrobe

/obj/machinery/vending/dinnerware
	name = "\improper Plasteel Chef's Dinnerware Vendor"
	desc = "A kitchen and restaurant equipment vendor."
	ads_list = list("Mm, food stuffs!","Food and food accessories.","Get your plates!","You like forks?","I like forks.","Woo, utensils.","You don't really need these...")
	icon_state = "dinnerware"
	icon_lightmask = "dinnerware"
	products = list(/obj/item/storage/bag/tray = 8,
					/obj/item/kitchen/utensil/fork = 6,
					/obj/item/trash/plate = 20,
					/obj/item/trash/bowl = 20,
					/obj/item/kitchen/knife = 3,
					/obj/item/kitchen/rollingpin = 2,
					/obj/item/kitchen/sushimat = 3,
					/obj/item/reagent_containers/food/drinks/drinkingglass = 8,
					/obj/item/clothing/suit/chef/classic = 2,
					/obj/item/storage/belt/chef = 2,
					/obj/item/reagent_containers/food/condiment/pack/ketchup = 5,
					/obj/item/reagent_containers/food/condiment/pack/hotsauce = 5,
					/obj/item/reagent_containers/food/condiment/saltshaker =5,
					/obj/item/reagent_containers/food/condiment/peppermill =5,
					/obj/item/whetstone = 2,
					/obj/item/mixing_bowl = 10,
					/obj/item/kitchen/mould/bear = 1, /obj/item/kitchen/mould/worm = 1,
					/obj/item/kitchen/mould/bean = 1, /obj/item/kitchen/mould/ball = 1,
					/obj/item/kitchen/mould/cane = 1, /obj/item/kitchen/mould/cash = 1,
					/obj/item/kitchen/mould/coin = 1, /obj/item/kitchen/mould/loli = 1,
					/obj/item/kitchen/cutter = 2)
	contraband = list(/obj/item/kitchen/rollingpin = 2, /obj/item/kitchen/knife/butcher = 2)
	refill_canister = /obj/item/vending_refill/dinnerware

/obj/machinery/vending/sovietsoda
	name = "\improper BODA"
	desc = "Old sweet water vending machine."
	icon_state = "sovietsoda"
	icon_lightmask = "sovietsoda"
	ads_list = list("For Tsar and Country.","Have you fulfilled your nutrition quota today?","Very nice!","We are simple people, for this is all we eat.","If there is a person, there is a problem. If there is no person, then there is no problem.")
	products = list(/obj/item/reagent_containers/food/drinks/drinkingglass/soda = 30)
	contraband = list(/obj/item/reagent_containers/food/drinks/drinkingglass/cola = 20)
	resistance_flags = FIRE_PROOF
	refill_canister = /obj/item/vending_refill/sovietsoda

/obj/machinery/vending/tool
	name = "\improper YouTool"
	desc = "Tools for tools."
	icon_state = "tool"
	icon_deny = "tool_deny"
	icon_lightmask = "tool"
	icon_panel = "generic"
	armor = list(melee = 50, bullet = 20, laser = 20, energy = 20, bomb = 0, bio = 0, rad = 0, fire = 100, acid = 70)
	resistance_flags = FIRE_PROOF
	products = list(/obj/item/stack/cable_coil/random = 10,/obj/item/crowbar = 5,/obj/item/weldingtool = 3,/obj/item/wirecutters = 5,
					/obj/item/wrench = 5,/obj/item/analyzer = 5,/obj/item/t_scanner = 5,/obj/item/screwdriver = 5)
	contraband = list(/obj/item/weldingtool/hugetank = 2,/obj/item/clothing/gloves/color/fyellow = 2)
	premium = list(/obj/item/clothing/gloves/color/yellow = 1)
	refill_canister = /obj/item/vending_refill/youtool

/obj/machinery/vending/engivend
	name = "\improper Engi-Vend"
	desc = "Spare tool vending. What? Did you expect some witty description?"
	icon_state = "engivend"
	icon_deny = "engivend_deny"
	icon_panel = "generic"
	req_one_access_txt = "11;24" // Engineers and atmos techs can use this
	products = list(/obj/item/clothing/glasses/meson/engine = 2,/obj/item/multitool = 4, /obj/item/geiger_counter = 5, /obj/item/airlock_electronics = 10,/obj/item/firelock_electronics = 10,/obj/item/firealarm_electronics = 10,/obj/item/apc_electronics = 10,/obj/item/airalarm_electronics = 10,/obj/item/stock_parts/cell/high = 10,/obj/item/camera_assembly = 10)
	contraband = list(/obj/item/stock_parts/cell/potato = 3)
	premium = list(/obj/item/storage/belt/utility = 3)
	refill_canister = /obj/item/vending_refill/engivend

/obj/machinery/vending/engineering
	name = "\improper Robco Tool Maker"
	desc = "Everything you need for do-it-yourself station repair."
	icon_state = "engi"
	icon_deny = "engi_deny"
	req_access_txt = "11"
	products = list(/obj/item/clothing/under/rank/engineering/chief_engineer = 4,/obj/item/clothing/under/rank/engineering/engineer = 4,/obj/item/clothing/shoes/workboots = 4,/obj/item/clothing/head/hardhat = 4,
					/obj/item/storage/belt/utility = 4,/obj/item/clothing/glasses/meson/engine = 4,/obj/item/clothing/gloves/color/yellow = 4, /obj/item/screwdriver = 12,
					/obj/item/crowbar = 12,/obj/item/wirecutters = 12,/obj/item/multitool = 12,/obj/item/wrench = 12,/obj/item/t_scanner = 12,
					/obj/item/stack/cable_coil = 8, /obj/item/stock_parts/cell = 8, /obj/item/weldingtool = 8,/obj/item/clothing/head/welding = 8,
					/obj/item/light/tube = 10,/obj/item/clothing/suit/fire = 4, /obj/item/stock_parts/scanning_module = 5,/obj/item/stock_parts/micro_laser = 5,
					/obj/item/stock_parts/matter_bin = 5,/obj/item/stock_parts/manipulator = 5)
	refill_canister = /obj/item/vending_refill/engineering

/obj/machinery/vending/robotics
	name = "\improper Robotech Deluxe"
	desc = "All the tools you need to create your own robot army."
	icon_state = "robotics"
	icon_deny = "robotics_deny"
	icon_lightmask = "robotics"
	req_access_txt = "29"
	products = list(/obj/item/clothing/suit/storage/labcoat = 4,/obj/item/clothing/under/rank/rnd/roboticist = 4,/obj/item/stack/cable_coil = 4,/obj/item/flash = 4,
					/obj/item/stock_parts/cell/high = 12, /obj/item/assembly/prox_sensor = 3,/obj/item/assembly/signaler = 3,/obj/item/healthanalyzer = 3,
					/obj/item/scalpel = 2,/obj/item/circular_saw = 2,/obj/item/tank/internals/anesthetic = 2,/obj/item/clothing/mask/breath/medical = 5,
					/obj/item/screwdriver = 5,/obj/item/crowbar = 5)
	refill_canister = /obj/item/vending_refill/robotics

/obj/machinery/vending/sustenance
	name = "\improper Sustenance Vendor"
	desc = "A vending machine which vends food, as required by section 47-C of the NT's Prisoner Ethical Treatment Agreement."
	slogan_list = list("Enjoy your meal.","Enough calories to support strenuous labor.")
	ads_list = list("The healthiest!","Award-winning chocolate bars!","Mmm! So good!","Oh my god it's so juicy!","Have a snack.","Snacks are good for you!","Have some more Getmore!","Best quality snacks straight from mars.","We love chocolate!","Try our new jerky!")
	icon_state = "sustenance"
	icon_lightmask = "nutri"
	icon_off = "nutri"
	icon_panel = "thin_vendor"
	products = list(/obj/item/reagent_containers/food/snacks/tofu = 24,
					/obj/item/reagent_containers/food/drinks/ice = 12,
					/obj/item/reagent_containers/food/snacks/candy/candy_corn = 6)
	contraband = list(/obj/item/kitchen/knife = 6,
					  /obj/item/reagent_containers/food/drinks/coffee = 12,
					  /obj/item/tank/internals/emergency_oxygen = 6,
					  /obj/item/clothing/mask/breath = 6)
	refill_canister = /obj/item/vending_refill/sustenance

/obj/machinery/vending/hatdispenser
	name = "\improper Hatlord 9000"
	desc = "It doesn't seem the slightest bit unusual. This frustrates you immensely."
	icon_state = "hats"
	icon_lightmask = "hats"
	icon_panel = "syndi"
	icon_broken = "wide_vendor"
	ads_list = list("Warning, not all hats are dog/monkey compatible. Apply forcefully with care.","Apply directly to the forehead.","Who doesn't love spending cash on hats?!","From the people that brought you collectable hat crates, Hatlord!")
	products = list(/obj/item/clothing/head/bowlerhat = 10,
					/obj/item/clothing/head/beaverhat = 10,
					/obj/item/clothing/head/boaterhat = 10,
					/obj/item/clothing/head/fedora = 10,
					/obj/item/clothing/head/fez = 10,
					/obj/item/clothing/head/beret = 10)
	contraband = list(/obj/item/clothing/head/bearpelt = 5)
	premium = list(/obj/item/clothing/head/soft/rainbow = 1)
	refill_canister = /obj/item/vending_refill/hatdispenser

/obj/machinery/vending/suitdispenser
	name = "\improper Suitlord 9000"
	desc = "You wonder for a moment why all of your shirts and pants come conjoined. This hurts your head and you stop thinking about it."
	icon_state = "suits"
	icon_lightmask = "suits"
	icon_panel = "syndi"
	icon_broken = "wide_vendor"
	ads_list = list("Pre-Ironed, Pre-Washed, Pre-Wor-*BZZT*","Blood of your enemies washes right out!","Who are YOU wearing?","Look dapper! Look like an idiot!","Dont carry your size? How about you shave off some pounds you fat lazy- *BZZT*")
	products = list(/obj/item/clothing/under/color/black = 10, /obj/item/clothing/under/color/grey = 10, /obj/item/clothing/under/color/white = 10, /obj/item/clothing/under/color/darkred = 10, /obj/item/clothing/under/color/red = 10, /obj/item/clothing/under/color/lightred = 10,
					/obj/item/clothing/under/color/brown = 10, /obj/item/clothing/under/color/orange = 10, /obj/item/clothing/under/color/lightbrown = 10, /obj/item/clothing/under/color/yellow = 10, /obj/item/clothing/under/color/yellowgreen = 10, /obj/item/clothing/under/color/lightgreen = 10,
					/obj/item/clothing/under/color/green = 10, /obj/item/clothing/under/color/aqua = 10, /obj/item/clothing/under/color/darkblue = 10, /obj/item/clothing/under/color/blue = 10, /obj/item/clothing/under/color/lightblue = 10, /obj/item/clothing/under/color/purple = 10,
					/obj/item/clothing/under/color/lightpurple = 10, /obj/item/clothing/under/color/pink = 10)
	contraband = list(/obj/item/clothing/under/syndicate/tacticool = 5,/obj/item/clothing/under/color/orange/prison = 5)
	premium = list(/obj/item/clothing/under/color/rainbow = 1)
	refill_canister = /obj/item/vending_refill/suitdispenser

/obj/machinery/vending/shoedispenser
	name = "\improper Shoelord 9000"
	desc = "Wow, hatlord looked fancy, suitlord looked streamlined, and this is just normal. The guy who designed these must be an idiot."
	icon_state = "shoes"
	icon_lightmask = "shoes"
	icon_panel = "syndi"
	icon_broken = "wide_vendor"
	ads_list = list("Put your foot down!","One size fits all!","IM WALKING ON SUNSHINE!","No hobbits allowed.","NO PLEASE WILLY, DONT HURT ME- *BZZT*")
	products = list(/obj/item/clothing/shoes/black = 10,/obj/item/clothing/shoes/brown = 10,/obj/item/clothing/shoes/blue = 10,/obj/item/clothing/shoes/green = 10,/obj/item/clothing/shoes/yellow = 10,/obj/item/clothing/shoes/purple = 10,/obj/item/clothing/shoes/red = 10,/obj/item/clothing/shoes/white = 10,/obj/item/clothing/shoes/sandal=10)
	contraband = list(/obj/item/clothing/shoes/orange = 5)
	premium = list(/obj/item/clothing/shoes/rainbow = 1)
	refill_canister = /obj/item/vending_refill/shoedispenser

/obj/machinery/vending/syndicigs
	name = "\improper Suspicious Cigarette Machine"
	desc = "Smoke 'em if you've got 'em."
	slogan_list = list("Space cigs taste good like a cigarette should.","I'd rather toolbox than switch.","Smoke!","Don't believe the reports - smoke today!")
	ads_list = list("Probably not bad for you!","Don't believe the scientists!","It's good for you!","Don't quit, buy more!","Smoke!","Nicotine heaven.","Best cigarettes since 2150.","Award-winning cigs.")
	vend_delay = 34
	icon_state = "cigs"
	icon_lightmask = "cigs"
	products = list(/obj/item/storage/fancy/cigarettes/syndicate = 10,/obj/item/lighter/random = 5)

/obj/machinery/vending/syndisnack
	name = "\improper Getmore Chocolate Corp"
	desc = "A modified snack machine courtesy of the Getmore Chocolate Corporation, based out of Mars"
	slogan_list = list("Try our new nougat bar!","Twice the calories for half the price!")
	ads_list = list("The healthiest!","Award-winning chocolate bars!","Mmm! So good!","Oh my god it's so juicy!","Have a snack.","Snacks are good for you!","Have some more Getmore!","Best quality snacks straight from mars.","We love chocolate!","Try our new jerky!")
	icon_state = "snack"
	icon_lightmask = "nutri"
	icon_off = "nutri"
	icon_panel = "thin_vendor"
	products = list(/obj/item/reagent_containers/food/snacks/chips =6,/obj/item/reagent_containers/food/snacks/sosjerky = 6,
					/obj/item/reagent_containers/food/snacks/syndicake = 6, /obj/item/reagent_containers/food/snacks/cheesiehonkers = 6)

//don't forget to change the refill size if you change the machine's contents!
/obj/machinery/vending/clothing
	name = "\improper ClothesMate" //renamed to make the slogan rhyme
	desc = "A vending machine for clothing."
	icon_state = "clothes"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	slogan_list = list("Dress for success!","Prepare to look swagalicious!","Look at all this free swag!","Why leave style up to fate? Use the ClothesMate!")
	vend_delay = 15
	vend_reply = "Thank you for using the ClothesMate!"
	products = list(/obj/item/clothing/head/that = 2,
					/obj/item/clothing/head/fedora = 1,
					/obj/item/clothing/glasses/monocle = 1,
					/obj/item/clothing/under/suit/navy = 2,
					/obj/item/clothing/under/costume/kilt = 1,
					/obj/item/clothing/under/misc/overalls = 1,
					/obj/item/clothing/under/suit/really_black = 2,
					/obj/item/clothing/suit/storage/lawyer/blackjacket = 2,
					/obj/item/clothing/under/pants/jeans = 3,
					/obj/item/clothing/under/pants/classicjeans = 2,
					/obj/item/clothing/under/pants/camo = 1,
					/obj/item/clothing/under/pants/blackjeans = 2,
					/obj/item/clothing/under/pants/khaki = 2,
					/obj/item/clothing/under/pants/white = 2,
					/obj/item/clothing/under/pants/red = 1,
					/obj/item/clothing/under/pants/black = 2,
					/obj/item/clothing/under/pants/tan = 2,
					/obj/item/clothing/under/pants/blue = 1,
					/obj/item/clothing/under/pants/track = 1,
					/obj/item/clothing/suit/jacket/miljacket = 1,
					/obj/item/clothing/head/beanie = 3,
					/obj/item/clothing/head/beanie/black = 3,
					/obj/item/clothing/head/beanie/red = 3,
					/obj/item/clothing/head/beanie/green = 3,
					/obj/item/clothing/head/beanie/darkblue = 3,
					/obj/item/clothing/head/beanie/purple = 3,
					/obj/item/clothing/head/beanie/yellow = 3,
					/obj/item/clothing/head/beanie/orange = 3,
					/obj/item/clothing/head/beanie/cyan = 3,
					/obj/item/clothing/head/beanie/christmas = 3,
					/obj/item/clothing/head/beanie/striped = 3,
					/obj/item/clothing/head/beanie/stripedred = 3,
					/obj/item/clothing/head/beanie/stripedblue = 3,
					/obj/item/clothing/head/beanie/stripedgreen = 3,
					/obj/item/clothing/head/beanie/rasta = 3,
					/obj/item/clothing/accessory/scarf/red = 1,
					/obj/item/clothing/accessory/scarf/green = 1,
					/obj/item/clothing/accessory/scarf/darkblue = 1,
					/obj/item/clothing/accessory/scarf/purple = 1,
					/obj/item/clothing/accessory/scarf/yellow = 1,
					/obj/item/clothing/accessory/scarf/orange = 1,
					/obj/item/clothing/accessory/scarf/lightblue = 1,
					/obj/item/clothing/accessory/scarf/white = 1,
					/obj/item/clothing/accessory/scarf/black = 1,
					/obj/item/clothing/accessory/scarf/zebra = 1,
					/obj/item/clothing/accessory/scarf/christmas = 1,
					/obj/item/clothing/accessory/stripedredscarf = 1,
					/obj/item/clothing/accessory/stripedbluescarf = 1,
					/obj/item/clothing/accessory/stripedgreenscarf = 1,
					/obj/item/clothing/accessory/waistcoat = 1,
					/obj/item/clothing/under/dress/sundress = 2,
					/obj/item/clothing/under/dress/stripeddress = 1,
					/obj/item/clothing/under/dress/sailordress = 1,
					/obj/item/clothing/under/dress/redeveninggown = 1,
					/obj/item/clothing/under/dress/blacktango = 1,
					/obj/item/clothing/suit/jacket = 3,
					/obj/item/clothing/suit/jacket/motojacket = 3,
					/obj/item/clothing/glasses/regular = 2,
					/obj/item/clothing/glasses/sunglasses_fake = 2,
					/obj/item/clothing/head/sombrero = 1,
					/obj/item/clothing/suit/poncho = 1,
					/obj/item/clothing/suit/ianshirt = 1,
					/obj/item/clothing/shoes/laceup = 2,
					/obj/item/clothing/shoes/black = 4,
					/obj/item/clothing/shoes/sandal = 1,
					/obj/item/clothing/gloves/fingerless = 2,
					/obj/item/storage/belt/fannypack = 1,
					/obj/item/storage/belt/fannypack/blue = 1,
					/obj/item/storage/belt/fannypack/red = 1,
					/obj/item/clothing/suit/mantle = 2,
					/obj/item/clothing/suit/mantle/old = 1,
					/obj/item/clothing/suit/mantle/regal = 2)

	contraband = list(/obj/item/clothing/under/syndicate/tacticool = 1,
					  /obj/item/clothing/mask/balaclava = 1,
					  /obj/item/clothing/head/ushanka = 1,
					  /obj/item/clothing/under/costume/soviet = 1,
					  /obj/item/storage/belt/fannypack/black = 1)

	premium = list(/obj/item/clothing/under/suit/checkered = 1,
				   /obj/item/clothing/head/mailman = 1,
				   /obj/item/clothing/under/misc/mailman = 1,
				   /obj/item/clothing/suit/jacket/leather = 1,
				   /obj/item/clothing/under/pants/mustangjeans = 1)

	refill_canister = /obj/item/vending_refill/clothing

/obj/machinery/vending/artvend
	name = "\improper ArtVend"
	desc = "A vending machine for art supplies."
	slogan_list = list("Stop by for all your artistic needs!","Color the floors with crayons, not blood!","Don't be a starving artist, use ArtVend. ","Don't fart, do art!")
	ads_list = list("Just like Kindergarten!","Now with 1000% more vibrant colors!","Screwing with the janitor was never so easy!","Creativity is at the heart of every spessman.")
	vend_delay = 15
	icon_state = "artvend"
	icon_lightmask = "artvend"
	icon_panel = "screen_vendor"
	products = list(/obj/item/stack/cable_coil/random = 10,/obj/item/camera = 4,/obj/item/camera_film = 6,
	/obj/item/storage/photo_album = 2,/obj/item/stack/wrapping_paper = 4,/obj/item/stack/tape_roll = 5,/obj/item/stack/packageWrap = 4,
	/obj/item/storage/fancy/crayons = 4,/obj/item/hand_labeler = 4,/obj/item/paper = 10,
	/obj/item/c_tube = 10,/obj/item/pen = 5,/obj/item/pen/blue = 5,
	/obj/item/pen/red = 5)
	contraband = list(/obj/item/toy/crayon/mime = 1,/obj/item/toy/crayon/rainbow = 1)
	premium = list(/obj/item/poster/random_contraband = 5)

/obj/machinery/vending/crittercare
	name = "\improper CritterCare"
	desc = "A vending machine for pet supplies."
	slogan_list = list("Stop by for all your animal's needs!","Cuddly pets deserve a stylish collar!","Pets in space, what could be more adorable?","Freshest fish eggs in the system!","Rocks are the perfect pet, buy one today!")
	ads_list = list("House-training costs extra!","Now with 1000% more cat hair!","Allergies are a sign of weakness!","Dogs are man's best friend. Remember that Vulpkanin!"," Heat lamps for Unathi!"," Vox-y want a cracker?")
	vend_delay = 15
	icon_state = "crittercare"
	icon_lightmask = "crittercare"
	icon_panel = "drobe"
	products = list(/obj/item/clothing/accessory/petcollar = 5, /obj/item/storage/firstaid/aquatic_kit/full =5, /obj/item/fish_eggs/goldfish = 5,
					/obj/item/fish_eggs/clownfish = 5, /obj/item/fish_eggs/shark = 5, /obj/item/fish_eggs/feederfish = 10,
					/obj/item/fish_eggs/salmon = 5, /obj/item/fish_eggs/catfish = 5, /obj/item/fish_eggs/glofish = 5,
					/obj/item/fish_eggs/electric_eel = 5, /obj/item/fish_eggs/shrimp = 10, /obj/item/toy/pet_rock = 5,
					)
	prices = list(/obj/item/clothing/accessory/petcollar = 50, /obj/item/storage/firstaid/aquatic_kit/full = 60, /obj/item/fish_eggs/goldfish = 10,
					/obj/item/fish_eggs/clownfish = 10, /obj/item/fish_eggs/shark = 10, /obj/item/fish_eggs/feederfish = 5,
					/obj/item/fish_eggs/salmon = 10, /obj/item/fish_eggs/catfish = 10, /obj/item/fish_eggs/glofish = 10,
					/obj/item/fish_eggs/electric_eel = 10, /obj/item/fish_eggs/shrimp = 5, /obj/item/toy/pet_rock = 100,
					)
	contraband = list(/obj/item/fish_eggs/babycarp = 5)
	premium = list(/obj/item/toy/pet_rock/fred = 1, /obj/item/toy/pet_rock/roxie = 1)
	refill_canister = /obj/item/vending_refill/crittercare

/obj/machinery/vending/crittercare/free
	prices = list()

//Departmental clothing vendors

/obj/machinery/vending/secdrobe
	name = "\improper SecDrobe"
	desc = "A vending machine for security and security-related clothing!"
	icon_state = "secdrobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	ads_list = list("Beat perps in style!", "It's red so you can't see the blood!", "You have the right to be fashionable!", "Now you can be the fashion police you always wanted to be!")
	vend_reply = "Thank you for using the SecDrobe!"
	products = list(/obj/item/clothing/under/rank/security/officer/corporate = 4,
					/obj/item/clothing/under/rank/security/officer/skirt/corporate = 4,
					/obj/item/clothing/under/rank/security/officer/dispatch = 4,
					/obj/item/clothing/under/rank/security/officer/skirt = 4,
					/obj/item/clothing/under/rank/security/officer = 4,
					/obj/item/clothing/under/rank/security/officer/uniform = 4,
					/obj/item/clothing/under/rank/security/formal = 4,
					/obj/item/clothing/under/rank/security/officer/fancy = 4,
					/obj/item/clothing/under/rank/security/officer/skirt/fancy = 4,
					/obj/item/clothing/head/soft/sec/corp = 4,
					/obj/item/clothing/head/officer = 4,
					/obj/item/clothing/head/beret/sec = 4,
					/obj/item/clothing/head/soft/sec = 4,
					/obj/item/clothing/head/drillsgt = 4,
					/obj/item/clothing/mask/bandana/red = 4,
					/obj/item/clothing/suit/jacket/secbomber = 2,
					/obj/item/clothing/suit/armor/secjacket = 4,
					/obj/item/clothing/suit/hooded/wintercoat/security = 4,
					/obj/item/clothing/shoes/jackboots = 4,
					/obj/item/clothing/shoes/jackboots/jacksandals = 4,
					/obj/item/clothing/shoes/laceup = 4,
					/obj/item/storage/backpack/duffel/security = 2,
					/obj/item/storage/backpack/security = 2,
					/obj/item/storage/backpack/satchel_sec = 2,
					/obj/item/clothing/gloves/color/black = 4,
					/obj/item/clothing/accessory/armband/sec = 6)
	premium = list(/obj/item/clothing/mask/balaclava = 1,
				   /obj/item/clothing/mask/gas/sechailer/swat = 2)
	contraband = list(/obj/item/toy/figure/crew/hos = 1,
					  /obj/item/toy/figure/crew/secofficer = 1)
	refill_canister = /obj/item/vending_refill/secdrobe

/obj/machinery/vending/detdrobe
	name = "\improper DetDrobe"
	desc = "A machine for all your detective needs, as long as you only need clothes."
	icon_state = "detdrobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	ads_list = list("Apply your brilliant deductive methods in style!", "They already smell of cigarettes!")
	vend_reply = "Thank you for using the DetDrobe!"
	products = list(/obj/item/clothing/under/rank/security/detective = 2,
					/obj/item/clothing/suit/storage/det_suit = 2,
					/obj/item/clothing/suit/storage/det_suit/forensics/red = 1,
					/obj/item/clothing/suit/storage/det_suit/forensics/blue = 1,
					/obj/item/clothing/suit/armor/vest/det_suit = 1,
					/obj/item/clothing/head/det_hat = 2,
					/obj/item/clothing/glasses/sunglasses/noir = 2,
					/obj/item/clothing/accessory/waistcoat = 2,
					/obj/item/clothing/shoes/laceup = 2,
					/obj/item/clothing/shoes/brown = 2,
					/obj/item/clothing/shoes/jackboots = 2,
					/obj/item/clothing/head/fedora = 1,
					/obj/item/clothing/head/fedora/brownfedora = 1,
					/obj/item/clothing/head/fedora/whitefedora = 1,
					/obj/item/clothing/gloves/color/black = 2,
					/obj/item/clothing/gloves/color/latex = 2,
					/obj/item/reagent_containers/food/drinks/flask/detflask = 2,
					/obj/item/storage/fancy/cigarettes/dromedaryco = 5)
	contraband = list(/obj/item/toy/figure/crew/detective = 1)
	refill_canister = /obj/item/vending_refill/detdrobe

/obj/machinery/vending/medidrobe
	name = "\improper MediDrobe"
	desc = "A vending machine rumoured to be capable of dispensing clothing for medical personnel."
	icon_state = "base_drobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	icon_addon = "medidrobe"
	ads_list = list("Make those blood stains look fashionable!")
	vend_reply = "Thank you for using the MediDrobe!"
	products = list(/obj/item/clothing/under/rank/medical/doctor = 3,
					/obj/item/clothing/under/rank/medical/doctor/skirt = 3,
					/obj/item/clothing/under/rank/medical/scrubs = 3,
					/obj/item/clothing/under/rank/medical/scrubs/green = 3,
					/obj/item/clothing/under/rank/medical/scrubs/purple = 3,
					/obj/item/clothing/under/rank/medical/nurse = 3,
					/obj/item/clothing/under/rank/medical/gown = 3,
					/obj/item/clothing/head/beret/med = 3,
					/obj/item/clothing/head/surgery/blue = 3,
					/obj/item/clothing/head/surgery/green = 3,
					/obj/item/clothing/head/surgery/purple = 3,
					/obj/item/clothing/head/nursehat = 3,
					/obj/item/clothing/suit/hooded/wintercoat/medical = 3,
					/obj/item/clothing/suit/storage/fr_jacket = 3,
					/obj/item/clothing/suit/storage/labcoat = 3,
					/obj/item/clothing/accessory/armband/med = 3,
					/obj/item/clothing/accessory/armband/medgreen = 3,
					/obj/item/clothing/shoes/laceup = 3,
					/obj/item/clothing/shoes/white = 3,
					/obj/item/clothing/shoes/sandal/white = 3,
					/obj/item/storage/backpack/medic = 2,
					/obj/item/storage/backpack/satchel_med = 2,
					/obj/item/storage/backpack/duffel/medical = 2)
	premium = list(/obj/item/clothing/gloves/color/latex/nitrile = 3)
	contraband = list(/obj/item/toy/figure/crew/md = 1)
	refill_canister = /obj/item/vending_refill/medidrobe

/obj/machinery/vending/virodrobe
	name = "\improper ViroDrobe"
	desc = "An unsterilized machine for dispending virology related clothing."
	icon_state = "base_drobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	icon_addon = "virodrobe"
	ads_list = list("Viruses getting you down? Nothing a change of clothes can't fix!", "Upgrade to sterilized clothing today!")
	vend_reply = "Thank you for using the ViroDrobe!"
	products = list(/obj/item/clothing/under/rank/medical/virologist = 2,
					/obj/item/clothing/under/rank/medical/virologist/skirt = 2,
					/obj/item/clothing/head/beret/med = 2,
					/obj/item/clothing/suit/storage/labcoat/virologist = 2,
					/obj/item/clothing/accessory/armband/med = 2,
					/obj/item/clothing/mask/surgical = 2,
					/obj/item/clothing/shoes/laceup = 2,
					/obj/item/clothing/shoes/white = 2,
					/obj/item/clothing/shoes/sandal/white = 2,
					/obj/item/storage/backpack/virology = 2,
					/obj/item/storage/backpack/satchel_vir = 2,
					/obj/item/storage/backpack/duffel/virology = 2)
	contraband = list(/obj/item/toy/figure/crew/virologist = 1)
	refill_canister = /obj/item/vending_refill/virodrobe

/obj/machinery/vending/chemdrobe
	name = "\improper ChemDrobe"
	desc = "A vending machine for dispensing chemistry related clothing."
	icon_state = "base_drobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	icon_addon = "chemdrobe"
	ads_list = list("Our clothes are 0.5% more resistant to acid spills! Get yours now!")
	vend_reply = "Thank you for using the ChemDrobe!"
	products = list(/obj/item/clothing/under/rank/medical/chemist = 2,
					/obj/item/clothing/under/rank/medical/chemist/skirt = 2,
					/obj/item/clothing/head/beret/med = 2,
					/obj/item/clothing/suit/storage/labcoat/chemist = 2,
					/obj/item/clothing/accessory/armband/med = 2,
					/obj/item/clothing/mask/gas = 2,
					/obj/item/clothing/shoes/laceup = 2,
					/obj/item/clothing/shoes/white = 2,
					/obj/item/clothing/shoes/sandal/white = 2,
					/obj/item/storage/bag/chemistry = 2,
					/obj/item/storage/backpack/chemistry = 2,
					/obj/item/storage/backpack/satchel_chem = 2,
					/obj/item/storage/backpack/duffel/chemistry = 2)
	contraband = list(/obj/item/toy/figure/crew/chemist = 1)
	refill_canister = /obj/item/vending_refill/chemdrobe

/obj/machinery/vending/genedrobe
	name = "\improper GeneDrobe"
	desc = "A machine for dispensing clothing related to genetics."
	icon_state = "base_drobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	icon_addon = "genedrobe"
	ads_list = "Perfect for the mad scientist in you!"
	vend_reply = "Thank you for using the GeneDrobe!"
	products = list(/obj/item/clothing/under/rank/rnd/geneticist = 3,
					/obj/item/clothing/suit/storage/labcoat/genetics = 3,
					/obj/item/clothing/shoes/laceup = 3,
					/obj/item/clothing/shoes/white = 3,
					/obj/item/clothing/shoes/sandal/white = 3,
					/obj/item/storage/backpack/genetics = 2,
					/obj/item/storage/backpack/satchel_gen = 2,
					/obj/item/storage/backpack/duffel/genetics = 2,)
	contraband = list(/obj/item/toy/figure/crew/geneticist = 1)
	refill_canister = /obj/item/vending_refill/genedrobe

/obj/machinery/vending/scidrobe
	name = "\improper SciDrobe"
	desc = "A simple vending machine suitable to dispense well tailored science clothing. Endorsed by Space Cubans."
	icon_state = "base_drobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	icon_addon = "scidrobe"
	ads_list = list("Longing for the smell of plasma burnt flesh?", "Buy your science clothing now!", "Made with 10% Auxetics, so you don't have to worry about losing your arm!")
	vend_reply = "Thank you for using the SciDrobe!"
	products = list(/obj/item/clothing/under/rank/rnd/scientist = 6,
					/obj/item/clothing/under/rank/rnd/scientist/skirt = 3,
					/obj/item/clothing/suit/hooded/wintercoat/science = 3,
					/obj/item/clothing/suit/storage/labcoat/science = 3,
					/obj/item/clothing/head/beret/sci = 3,
					/obj/item/clothing/accessory/armband/science = 6,
					/obj/item/clothing/shoes/laceup = 3,
					/obj/item/clothing/shoes/white = 3,
					/obj/item/clothing/shoes/sandal/white = 3,
					/obj/item/storage/backpack/science = 2,
					/obj/item/storage/backpack/satchel_tox = 2,
					/obj/item/storage/backpack/duffel/science = 2,)
	contraband = list(/obj/item/toy/figure/crew/rd = 1,
				      /obj/item/toy/figure/crew/scientist = 1)
	refill_canister = /obj/item/vending_refill/scidrobe

/obj/machinery/vending/robodrobe
	name = "\improper RoboDrobe"
	desc = "A vending machine designed to dispense clothing known only to roboticists."
	icon_state = "base_drobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	icon_addon = "robodrobe"
	ads_list = list("You turn me TRUE, use defines!","0110001101101100011011110111010001101000011001010111001101101000011001010111001001100101")
	vend_reply = "Thank you for using the RoboDrobe!"
	products = list(/obj/item/clothing/under/rank/rnd/roboticist = 3,
					/obj/item/clothing/under/rank/rnd/roboticist/skirt = 3,
					/obj/item/clothing/suit/storage/labcoat = 3,
					/obj/item/clothing/head/soft/black = 3,
					/obj/item/clothing/gloves/fingerless = 3,
					/obj/item/clothing/shoes/laceup = 3,
					/obj/item/clothing/shoes/white = 3,
					/obj/item/clothing/shoes/black = 3)
	contraband = list(/obj/item/toy/figure/crew/roboticist = 1)
	refill_canister = /obj/item/vending_refill/robodrobe

/obj/machinery/vending/engidrobe
	name = "\improper EngiDrobe"
	desc = "A vending machine renowned for vending industrial grade clothing."
	icon_state = "yellow_drobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	icon_addon = "engidrobe"
	ads_list = list("Guaranteed to protect your feet from industrial accidents!", "Afraid of radiation? Then wear yellow!")
	vend_reply = "Thank you for using the EngiDrobe!"
	products = list(/obj/item/clothing/under/rank/engineering/engineer = 6,
					/obj/item/clothing/under/rank/engineering/engineer/skirt = 3,
					/obj/item/clothing/suit/hooded/wintercoat/engineering = 3,
					/obj/item/clothing/suit/jacket/engibomber = 3,
					/obj/item/clothing/suit/storage/hazardvest = 3,
					/obj/item/clothing/head/beret/eng = 3,
					/obj/item/clothing/head/hardhat = 2,
					/obj/item/clothing/head/hardhat/orange = 2,
					/obj/item/clothing/head/hardhat/dblue = 2,
					/obj/item/clothing/accessory/armband/engine = 6,
					/obj/item/clothing/shoes/laceup = 3,
					/obj/item/clothing/shoes/workboots = 3,
					/obj/item/storage/backpack/industrial = 2,
					/obj/item/storage/backpack/satchel_eng = 2,
					/obj/item/storage/backpack/duffel/engineering = 2,
					/obj/item/storage/belt/utility = 2)
	premium = list(/obj/item/clothing/gloves/color/yellow = 2)
	contraband = list(/obj/item/toy/figure/crew/ce = 1,
				      /obj/item/toy/figure/crew/engineer = 1)
	refill_canister = /obj/item/vending_refill/engidrobe

/obj/machinery/vending/atmosdrobe
	name = "\improper AtmosDrobe"
	desc = "This relatively unknown vending machine delivers clothing for Atmospherics Technicians, an equally unknown job."
	icon_state = "yellow_drobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	icon_addon = "atmosdrobe"
	ads_list = list("Guaranteed to protect your feet from atmospheric accidents!", "Get your inflammable clothing right here!")
	vend_reply = "Thank you for using the AtmosDrobe!"
	products = list(/obj/item/clothing/under/rank/engineering/atmospheric_technician  = 6,
					/obj/item/clothing/under/rank/engineering/atmospheric_technician/skirt = 3,
					/obj/item/clothing/suit/hooded/wintercoat/engineering/atmos = 3,
					/obj/item/clothing/suit/jacket/atmosbomber = 3,
					/obj/item/clothing/suit/storage/hazardvest = 3,
					/obj/item/clothing/head/beret/atmos = 3,
					/obj/item/clothing/head/hardhat = 2,
					/obj/item/clothing/head/hardhat/red = 2,
					/obj/item/clothing/head/hardhat/orange = 2,
					/obj/item/clothing/head/hardhat/dblue = 2,
					/obj/item/clothing/gloves/color/black = 3,
					/obj/item/clothing/accessory/armband/engine = 3,
					/obj/item/clothing/shoes/laceup = 3,
					/obj/item/clothing/shoes/workboots = 3,
					/obj/item/storage/backpack/industrial/atmos = 2,
					/obj/item/storage/backpack/satchel_atmos = 2,
					/obj/item/storage/backpack/duffel/atmos = 2,
					/obj/item/storage/belt/utility = 2)
	contraband = list(/obj/item/toy/figure/crew/atmos = 1)
	refill_canister = /obj/item/vending_refill/atmosdrobe

/obj/machinery/vending/cargodrobe
	name = "\improper CargoDrobe"
	desc = "A highly advanced vending machine for buying cargo related clothing for free... most of the time."
	icon_state = "yellow_drobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	icon_addon = "cargodrobe"
	ads_list = list("Upgraded Assistant Style! Pick yours today!", "These shorts are comfy and easy to wear, get yours now!")
	vend_reply = "Thank you for using the CargoDrobe!"
	products = list(/obj/item/clothing/under/rank/cargo/tech = 6,
					/obj/item/clothing/under/rank/cargo/tech/skirt = 3,
					/obj/item/clothing/suit/hooded/wintercoat/cargo = 3,
					/obj/item/clothing/suit/jacket/cargobomber = 3,
					/obj/item/clothing/suit/storage/hazardvest = 3,
					/obj/item/clothing/head/soft = 3,
					/obj/item/clothing/head/hardhat/orange = 2,
					/obj/item/clothing/gloves/fingerless = 6,
					/obj/item/clothing/accessory/armband/cargo = 6,
					/obj/item/clothing/shoes/black = 3,
					/obj/item/clothing/shoes/workboots = 3)
	contraband = list(/obj/item/toy/figure/crew/qm = 1,
					  /obj/item/toy/figure/crew/cargotech = 1)
	refill_canister = /obj/item/vending_refill/cargodrobe

/obj/machinery/vending/chefdrobe
	name = "\improper ChefDrobe"
	desc = "This vending machine might not dispense meat, but it certainly dispenses chef related clothing."
	icon_state = "base_drobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	icon_addon = "chefdrobe"
	ads_list = list("Our clothes are guaranteed to protect you from food splatters!", "Comfortable enough for a CQC practice!")
	vend_reply = "Thank you for using the ChefDrobe!"
	products = list(/obj/item/clothing/under/rank/civilian/chef = 2,
					/obj/item/clothing/under/misc/waiter = 2,
					/obj/item/clothing/suit/chef = 2,
					/obj/item/clothing/suit/chef/classic = 2,
					/obj/item/clothing/head/chefhat = 2,
					/obj/item/clothing/head/soft/mime = 2,
					/obj/item/clothing/shoes/laceup = 2,
					/obj/item/clothing/shoes/white = 2,
					/obj/item/clothing/shoes/black = 2,
					/obj/item/clothing/accessory/waistcoat = 2,
					/obj/item/reagent_containers/glass/rag = 3)
	contraband = list(/obj/item/toy/figure/crew/chef = 1)
	premium = list(/obj/item/storage/box/dish_drive = 1)
	refill_canister = /obj/item/vending_refill/chefdrobe

/obj/machinery/vending/bardrobe
	name = "\improper BarDrobe"
	desc = "A stylish vendor to dispense the most stylish bar clothing!"
	icon_state = "bardrobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	ads_list = list("Guaranteed to prevent stains from spilled drinks!")
	vend_reply = "Thank you for using the BarDrobe!"
	products = list(/obj/item/clothing/under/rank/civilian/bartender = 2,
					/obj/item/clothing/under/misc/sl_suit = 2,
					/obj/item/clothing/head/that = 2,
					/obj/item/clothing/head/soft/black = 2,
					/obj/item/clothing/suit/blacktrenchcoat = 2,
					/obj/item/clothing/shoes/laceup = 2,
					/obj/item/clothing/shoes/black = 2,
					/obj/item/clothing/accessory/waistcoat = 2,
					/obj/item/reagent_containers/glass/rag = 3)
	contraband = list(/obj/item/toy/figure/crew/bartender = 1)
	premium = list(/obj/item/storage/box/dish_drive = 1)
	refill_canister = /obj/item/vending_refill/bardrobe

/obj/machinery/vending/hydrodrobe
	name = "\improper HydroDrobe"
	desc = "A machine with a catchy name. It dispenses botany related clothing and gear."
	icon_state = "hydrobe"
	icon_lightmask = "base_drobe"
	icon_panel = "drobe"
	ads_list = list("Do you love soil? Then buy our clothes!", "Get outfits to match your green thumb here!")
	vend_reply = "Thank you for using the HydroDrobe!"
	products = list(/obj/item/clothing/under/rank/civilian/hydroponics = 3,
					/obj/item/reagent_containers/glass/bucket = 3,
					/obj/item/clothing/suit/apron = 3,
					/obj/item/clothing/suit/apron/overalls = 3,
					/obj/item/clothing/mask/bandana/botany = 3,
					/obj/item/clothing/accessory/armband/hydro = 3,
					/obj/item/storage/backpack/botany = 2,
					/obj/item/storage/backpack/satchel_hyd = 2,
					/obj/item/storage/backpack/duffel/hydro = 2,)
	contraband = list(/obj/item/toy/figure/crew/botanist = 1)
	refill_canister = /obj/item/vending_refill/hydrodrobe

GLOBAL_VAR(claw_game_html)

/obj/machinery/arcade/claw
	name = "Claw Game"
	desc = "One of the most infuriating ways to win a toy."
	icon = 'icons/obj/arcade.dmi'
	icon_state = "clawmachine_1_on"
	token_price = 5
	window_name = "Claw Game"
	var/machine_image = "_1"
	var/bonus_prize_chance = 5		//chance to dispense a SECOND prize if you win, increased by matter bin rating
	//This is to make sure the images are available
	var/list/img_resources = list('icons/obj/arcade_images/backgroundsprite.png',
								'icons/obj/arcade_images/clawpieces.png',
								'icons/obj/arcade_images/crane_bot.png',
								'icons/obj/arcade_images/crane_top.png',
								'icons/obj/arcade_images/prize_inside.png',
								'icons/obj/arcade_images/prizeorbs.png')

/obj/machinery/arcade/claw/Initialize(mapload)
	. = ..()
	machine_image = pick("_1", "_2")
	update_icon(UPDATE_ICON_STATE)

	component_parts = list()
	component_parts += new /obj/item/circuitboard/clawgame(null)
	component_parts += new /obj/item/stock_parts/matter_bin(null)
	component_parts += new /obj/item/stock_parts/manipulator(null)
	component_parts += new /obj/item/stack/cable_coil(null, 5)
	component_parts += new /obj/item/stack/sheet/glass(null, 1)
	RefreshParts()

	if(!GLOB.claw_game_html)
		GLOB.claw_game_html = file2text('code/modules/arcade/crane.html')

/obj/machinery/arcade/claw/RefreshParts()
	var/bin_upgrades = 0
	for(var/obj/item/stock_parts/matter_bin/B in component_parts)
		bin_upgrades = B.rating
	bonus_prize_chance = bin_upgrades * 5	//equals +5% chance per matter bin rating level (+20% with rating 4)

/obj/machinery/arcade/claw/update_icon_state()
	if(stat & BROKEN)
		icon_state = "clawmachine[machine_image]_broken"
	else if(panel_open)
		icon_state = "clawmachine[machine_image]_open"
	else if(stat & NOPOWER)
		icon_state = "clawmachine[machine_image]_off"
	else
		icon_state = "clawmachine[machine_image]_on"

/obj/machinery/arcade/claw/win()
	icon_state = "clawmachine[machine_image]_win"
	if(prob(bonus_prize_chance))	//double prize mania!
		atom_say("DOUBLE PRIZE!")
		new /obj/item/toy/prizeball(get_turf(src))
	else
		atom_say("WINNER!")
	new /obj/item/toy/prizeball(get_turf(src))
	playsound(loc, 'sound/arcade/win.ogg', 50, TRUE)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom, update_icon), UPDATE_ICON_STATE), 10)

/obj/machinery/arcade/claw/start_play(mob/user as mob)
	..()
	user << browse_rsc('page.css')
	for(var/i in 1 to img_resources.len)
		user << browse_rsc(img_resources[i])
	var/my_game_html = replacetext(GLOB.claw_game_html, "/* ref src */", UID())
	var/datum/browser/popup = new(user, window_name, name, 915, 700, src)
	popup.set_content(my_game_html)
	popup.add_stylesheet("page.css", 'code/modules/arcade/page.css')
	popup.add_stylesheet("Button.scss", 'tgui/packages/tgui/styles/components/Button.scss')
	popup.add_script("jquery-1.8.2.min.js", 'html/browser/jquery-1.8.2.min.js')
	popup.add_script("jquery-ui-1.8.24.custom.min.js", 'html/browser/jquery-ui-1.8.24.custom.min.js')
	popup.open()
	user.set_machine(src)

/obj/machinery/arcade/claw/Topic(href, list/href_list)
	if(..())
		return
	var/prize_won = null
	prize_won = href_list["prizeWon"]
	if(!isnull(prize_won))
		close_game()
		if(prize_won == "1")
			win()

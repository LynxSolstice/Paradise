//Few global vars to track the blob
GLOBAL_LIST_EMPTY(blobs)
GLOBAL_LIST_EMPTY(blob_cores)
GLOBAL_LIST_EMPTY(blob_nodes)

/datum/game_mode
	var/list/blob_overminds = list()

/datum/game_mode/blob
	name = "blob"
	config_tag = "blob"

	required_players = 30
	required_enemies = 1
	recommended_enemies = 1
	restricted_jobs = list("Cyborg", "AI")

	var/burst = 0

	var/cores_to_spawn = 1
	var/players_per_core = 30
	var/blob_point_rate = 3

	var/blobwincount = 350

	var/list/infected_crew = list()

/datum/game_mode/blob/pre_setup()

	var/list/possible_blobs = get_players_for_role(ROLE_BLOB)

	// stop setup if no possible traitors
	if(!possible_blobs.len)
		return 0

	cores_to_spawn = max(round(num_players()/players_per_core, 1), 1)

	blobwincount = initial(blobwincount) * cores_to_spawn


	for(var/j = 0, j < cores_to_spawn, j++)
		if(!possible_blobs.len)
			break

		var/datum/mind/blob = pick(possible_blobs)
		infected_crew += blob
		blob.special_role = SPECIAL_ROLE_BLOB
		blob.restricted_roles = restricted_jobs
		log_game("[key_name(blob)] has been selected as a Blob")
		possible_blobs -= blob

	if(!infected_crew.len)
		return 0
	..()
	return 1

/datum/game_mode/blob/proc/get_blob_candidates()
	var/list/candidates = list()
	for(var/mob/living/carbon/human/player in GLOB.player_list)
		if(!player.stat && player.mind && !player.client.skip_antag && !player.mind.special_role && !jobban_isbanned(player, ROLE_SYNDICATE) && (ROLE_BLOB in player.client.prefs.be_special))
			candidates += player
	return candidates


/datum/game_mode/blob/proc/blobize(mob/living/carbon/human/blob)
	var/datum/mind/blobmind = blob.mind
	if(!istype(blobmind))
		return 0

	infected_crew += blobmind
	blobmind.special_role = SPECIAL_ROLE_BLOB
	update_blob_icons_added(blobmind)

	log_game("[key_name(blob)] has been selected as a Blob")
	greet_blob(blobmind)
	to_chat(blob, "<span class='userdanger'>You feel very tired and bloated!  You don't have long before you burst!</span>")
	addtimer(CALLBACK(src, PROC_REF(burst_blob), blobmind), 60 SECONDS)
	return 1

/datum/game_mode/blob/proc/make_blobs(count)
	var/list/candidates = get_blob_candidates()
	var/mob/living/carbon/human/blob = null
	count=min(count, candidates.len)
	for(var/i = 0, i < count, i++)
		blob = pick(candidates)
		candidates -= blob
		blobize(blob)
	return count



/datum/game_mode/blob/announce()
	to_chat(world, "<B>The current game mode is - <font color='green'>Blob</font>!</B>")
	to_chat(world, "<B>A dangerous alien organism is rapidly spreading throughout the station!</B>")
	to_chat(world, "You must kill it all while minimizing the damage to the station.")


/datum/game_mode/blob/proc/greet_blob(datum/mind/blob)
	to_chat(blob.current, "<span class='userdanger'>You are infected by the Blob!</span>")
	to_chat(blob.current, "<b>Your body is ready to give spawn to a new blob core which will eat this station.</b>")
	to_chat(blob.current, "<b>Find a good location to spawn the core and then take control and overwhelm the station!</b>")
	to_chat(blob.current, "<b>When you have found a location, wait until you spawn; this will happen automatically and you cannot speed up the process.</b>")
	to_chat(blob.current, "<b>If you go outside of the station level, or in space, then you will die; make sure your location has lots of ground to cover.</b>")
	to_chat(blob.current, "<span class='motd'>For more information, check the wiki page: ([GLOB.configuration.url.wiki_url]/index.php/Blob)</span>")
	SEND_SOUND(blob.current, sound('sound/magic/mutate.ogg'))
	return

/datum/game_mode/blob/proc/show_message(message)
	for(var/datum/mind/blob in infected_crew)
		to_chat(blob.current, message)

/datum/game_mode/blob/proc/burst_blobs()
	for(var/datum/mind/blob in infected_crew)
		burst_blob(blob)

/datum/game_mode/blob/proc/burst_blob(datum/mind/blob, warned=0)
	var/client/blob_client = null
	var/turf/location = null

	if(iscarbon(blob.current))
		var/mob/living/carbon/C = blob.current
		if(GLOB.directory[ckey(blob.key)])
			blob_client = GLOB.directory[ckey(blob.key)]
			location = get_turf(C)
			if(!is_station_level(location.z) || isspaceturf(location))
				if(!warned)
					to_chat(C, "<span class='userdanger'>You feel ready to burst, but this isn't an appropriate place!  You must return to the station!</span>")
					message_admins("[key_name_admin(C)] was in space when the blobs burst, and will die if [C.p_they()] [C.p_do()] not return to the station.")
					addtimer(CALLBACK(src, PROC_REF(burst_blob), blob, 1), 30 SECONDS)
				else
					burst++
					log_admin("[key_name(C)] was in space when attempting to burst as a blob.")
					message_admins("[key_name_admin(C)] was in space when attempting to burst as a blob.")
					C.gib()
					make_blobs(1)
					check_finished() //Still needed in case we can't make any blobs

			else if(blob_client && location)
				burst++
				C.gib()
				var/obj/structure/blob/core/core = new(location, blob_client, blob_point_rate)
				if(core.overmind && core.overmind.mind)
					core.overmind.mind.name = blob.name
					infected_crew -= blob
					infected_crew += core.overmind.mind
					core.overmind.mind.special_role = SPECIAL_ROLE_BLOB_OVERMIND

/datum/game_mode/blob/post_setup()

	for(var/datum/mind/blob in infected_crew)
		greet_blob(blob)
		update_blob_icons_added(blob)

	if(SSshuttle)
		SSshuttle.emergencyNoEscape = 1

	spawn(0)

		var/wait_time = rand(waittime_l, waittime_h)

		sleep(wait_time)

		send_intercept(0)

		sleep(100)

		show_message("<span class='userdanger'>You feel tired and bloated.</span>")

		sleep(wait_time)

		show_message("<span class='userdanger'>You feel like you are about to burst.</span>")

		addtimer(CALLBACK(src, PROC_REF(burst_blobs)), (wait_time / 2))

		// Stage 1
		addtimer(CALLBACK(src, PROC_REF(stage), 1), (wait_time * 2 + wait_time / 2))

		// Stage 2
		addtimer(CALLBACK(src, PROC_REF(stage), 2), 50 MINUTES)

	return ..()

/datum/game_mode/blob/proc/stage(stage)
	switch(stage)
		if(1)
			GLOB.event_announcement.Announce("Confirmed outbreak of level 5 biohazard aboard [station_name()]. All personnel must contain the outbreak.", "Biohazard Alert", 'sound/AI/outbreak5.ogg')
		if(2)
			send_intercept(1)

/datum/game_mode/proc/update_blob_icons_added(datum/mind/mob_mind)
	var/datum/atom_hud/antag/antaghud = GLOB.huds[ANTAG_HUD_BLOB]
	antaghud.join_hud(mob_mind.current)
	set_antag_hud(mob_mind.current, "hudblob")

/datum/game_mode/proc/update_blob_icons_removed(datum/mind/mob_mind)
	var/datum/atom_hud/antag/antaghud = GLOB.huds[ANTAG_HUD_BLOB]
	antaghud.leave_hud(mob_mind.current)
	set_antag_hud(mob_mind.current, null)

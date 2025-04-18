#define ROUND_START_MUSIC_LIST "strings/round_start_sounds.txt"

SUBSYSTEM_DEF(ticker)
	name = "Ticker"
	init_order = INIT_ORDER_TICKER

	priority = FIRE_PRIORITY_TICKER
	flags = SS_KEEP_TIMING
	runlevels = RUNLEVEL_LOBBY | RUNLEVEL_SETUP | RUNLEVEL_GAME

	var/current_state = GAME_STATE_STARTUP	//state of current round (used by process()) Use the defines GAME_STATE_* !
	var/force_ending = 0					//Round was ended by admin intervention
	// If true, there is no lobby phase, the game starts immediately.
	var/start_immediately = FALSE
	var/setup_done = FALSE //All game setup done including mode post setup and

	var/hide_mode = FALSE
	var/datum/game_mode/mode = null

	var/login_music							//music played in pregame lobby
	var/round_end_sound						//music/jingle played when the world reboots
	var/round_end_sound_sent = TRUE			//If all clients have loaded it

	var/list/datum/mind/minds = list()		//The characters in the game. Used for objective tracking.

	var/delay_end = FALSE						//if set true, the round will not restart on it's own
	var/admin_delay_notice = ""				//a message to display to anyone who tries to restart the world after a delay
	var/ready_for_reboot = FALSE			//all roundend preparation done with, all that's left is reboot

	///If set to an anonymous theme datum then people spawn with said themed anon name (see anonymousnames.dm)
	var/datum/anonymous_theme/anonymousnames
	///Boolean to see if the game needs to set up a triumvirate ai (see tripAI.dm)
	var/triai = FALSE

	var/tipped = FALSE							//Did we broadcast the tip of the day yet?
	var/selected_tip						// What will be the tip of the day?

	var/timeLeft						//pregame timer
	var/start_at

	var/gametime_offset = 432000		//Deciseconds to add to world.time for station time.
	var/station_time_rate_multiplier = 12		//factor of station time progressal vs real time.

	var/totalPlayers = 0					//used for pregame stats on statpanel
	var/totalPlayersReady = 0				//used for pregame stats on statpanel

	var/queue_delay = 0
	var/list/queued_players = list()		//used for join queues when the server exceeds the hard population cap

	var/news_report

	var/late_join_disabled

	var/roundend_check_paused = FALSE

	var/round_start_time = 0
	var/list/round_start_events
	var/list/round_end_events
	var/mode_result = "undefined"
	var/end_state = "undefined"

	/// People who have been commended and will receive a heart
	var/list/hearts

	/// Why an emergency shuttle was called
	var/emergency_reason

/datum/controller/subsystem/ticker/Initialize(timeofday)
	load_mode()

	var/list/byond_sound_formats = list(
		"mid"  = TRUE,
		"midi" = TRUE,
		"mod"  = TRUE,
		"it"   = TRUE,
		"s3m"  = TRUE,
		"xm"   = TRUE,
		"oxm"  = TRUE,
		"wav"  = TRUE,
		"ogg"  = TRUE,
		"raw"  = TRUE,
		"wma"  = TRUE,
		"aiff" = TRUE
	)

	var/list/provisional_title_music = flist("[global.config.directory]/title_music/sounds/")
	var/list/music = list()
	var/use_rare_music = prob(1)

	for(var/S in provisional_title_music)
		var/lower = lowertext(S)
		var/list/L = splittext(lower,"+")
		switch(L.len)
			if(3) //rare+MAP+sound.ogg or MAP+rare.sound.ogg -- Rare Map-specific sounds
				if(use_rare_music)
					if(L[1] == "rare" && L[2] == SSmapping.config.map_name)
						music += S
					else if(L[2] == "rare" && L[1] == SSmapping.config.map_name)
						music += S
			if(2) //rare+sound.ogg or MAP+sound.ogg -- Rare sounds or Map-specific sounds
				if((use_rare_music && L[1] == "rare") || (L[1] == SSmapping.config.map_name))
					music += S
			if(1) //sound.ogg -- common sound
				if(L[1] == "exclude")
					continue
				music += S

	var/old_login_music = trim(file2text("data/last_round_lobby_music.txt"))
	if(music.len > 1)
		music -= old_login_music

	for(var/S in music)
		var/list/L = splittext(S,".")
		if(L.len >= 2)
			var/ext = lowertext(L[L.len]) //pick the real extension, no 'honk.ogg.exe' nonsense here
			if(byond_sound_formats[ext])
				continue
		music -= S

	if(!length(music))
		music = world.file2list(ROUND_START_MUSIC_LIST, "\n")
		login_music = pick(music)
	else
		login_music = "[global.config.directory]/title_music/sounds/[pick(music)]"


	if(!GLOB.syndicate_code_phrase)
		GLOB.syndicate_code_phrase	= generate_code_phrase(return_list=TRUE)

		var/codewords = jointext(GLOB.syndicate_code_phrase, "|")
		var/regex/codeword_match = new("([codewords])", "ig")

		GLOB.syndicate_code_phrase_regex = codeword_match

	if(!GLOB.syndicate_code_response)
		GLOB.syndicate_code_response = generate_code_phrase(return_list=TRUE)

		var/codewords = jointext(GLOB.syndicate_code_response, "|")
		var/regex/codeword_match = new("([codewords])", "ig")

		GLOB.syndicate_code_response_regex = codeword_match

	start_at = world.time + (CONFIG_GET(number/lobby_countdown) * 10)
	if(CONFIG_GET(flag/randomize_shift_time))
		gametime_offset = rand(0, 23) HOURS
	else if(CONFIG_GET(flag/shift_time_realtime))
		gametime_offset = world.timeofday
	return ..()

/datum/controller/subsystem/ticker/fire()
	switch(current_state)
		if(GAME_STATE_STARTUP)
			if(Master.initializations_finished_with_no_players_logged_in)
				start_at = world.time + (CONFIG_GET(number/lobby_countdown) * 10)
			for(var/client/C in GLOB.clients)
				window_flash(C, ignorepref = TRUE) //let them know lobby has opened up.
			to_chat(world, "<span class='boldnotice'>Welcome to [station_name()]!</span>")
			send2chat("New round starting on [SSmapping.config.map_name]!", CONFIG_GET(string/chat_announce_new_game))
			current_state = GAME_STATE_PREGAME
			//Everyone who wants to be an observer is now spawned
			create_observers()
			fire()
		if(GAME_STATE_PREGAME)
				//lobby stats for statpanels
			if(isnull(timeLeft))
				timeLeft = max(0,start_at - world.time)
			totalPlayers = LAZYLEN(GLOB.new_player_list)
			totalPlayersReady = 0
			for(var/i in GLOB.new_player_list)
				var/mob/dead/new_player/player = i
				if(player.ready == PLAYER_READY_TO_PLAY)
					++totalPlayersReady

			if(start_immediately)
				timeLeft = 0

			//countdown
			if(timeLeft < 0)
				return
			timeLeft -= wait

			if(timeLeft <= 300 && !tipped)
				send_tip_of_the_round()
				tipped = TRUE

			if(timeLeft <= 0)
				current_state = GAME_STATE_SETTING_UP
				Master.SetRunLevel(RUNLEVEL_SETUP)
				if(start_immediately)
					fire()

		if(GAME_STATE_SETTING_UP)
			if(!setup())
				//setup failed
				current_state = GAME_STATE_STARTUP
				start_at = world.time + (CONFIG_GET(number/lobby_countdown) * 10)
				timeLeft = null
				Master.SetRunLevel(RUNLEVEL_LOBBY)

		if(GAME_STATE_PLAYING)
			mode.process(wait * 0.1)
			check_queue()

			if(!roundend_check_paused && mode.check_finished(force_ending) || force_ending)
				current_state = GAME_STATE_FINISHED
				toggle_ooc(TRUE) // Turn it on
				toggle_dooc(TRUE)
				declare_completion(force_ending)
				check_maprotate()
				Master.SetRunLevel(RUNLEVEL_POSTGAME)


/datum/controller/subsystem/ticker/proc/setup()
	to_chat(world, "<span class='boldannounce'>Starting game...</span>")
	var/init_start = world.timeofday
		//Create and announce mode
	var/list/datum/game_mode/runnable_modes
	if(GLOB.master_mode == "random" || GLOB.master_mode == "secret")
		runnable_modes = config.get_runnable_modes()

		if(GLOB.master_mode == "secret")
			hide_mode = 1
			if(GLOB.secret_force_mode != "secret")
				var/datum/game_mode/smode = config.pick_mode(GLOB.secret_force_mode)
				if(!smode.can_start())
					message_admins("<span class='notice'>Unable to force secret [GLOB.secret_force_mode]. [smode.required_players] players and [smode.required_enemies] eligible antagonists needed.</span>")
				else
					mode = smode

		if(!mode)
			if(!runnable_modes.len)
				to_chat(world, "<B>Unable to choose playable game mode.</B> Reverting to pre-game lobby.")
				return FALSE
			mode = pickweight(runnable_modes)
			if(!mode)	//too few roundtypes all run too recently
				mode = pick(runnable_modes)

	else
		mode = config.pick_mode(GLOB.master_mode)
		if(!mode.can_start())
			to_chat(world, "<B>Unable to start [mode.name].</B> Not enough players, [mode.required_players] players and [mode.required_enemies] eligible antagonists needed. Reverting to pre-game lobby.")
			qdel(mode)
			mode = null
			SSjob.ResetOccupations()
			return FALSE

	//These maps need all abnos breached.
	//Fucking Maptype initializes before Ticker so I need to do this here
	if(SSmaptype.maptype in SSmaptype.combatmaps)
		if(!(istype(mode, /datum/game_mode/combat)))
			mode = new /datum/game_mode/combat
	else

		switch(SSmaptype.chosen_trait)
			if(FACILITY_TRAIT_JOKE_ABNOS)
				mode = new /datum/game_mode/management/joke
			if(FACILITY_TRAIT_FUCKED_SELECTION)
				var/choosingmode = pick(
							/datum/game_mode/management/pure,
							/datum/game_mode/management/branch)
				mode = new choosingmode
			else
				mode = new /datum/game_mode/management/classic

		if(SSevents.holidays && SSevents.holidays[APRIL_FOOLS]) //runs in April 1st
			mode = new /datum/game_mode/management/joke

	CHECK_TICK

	//Configure mode and assign player to special mode stuff
	var/can_continue = 0
	can_continue = src.mode.pre_setup()		//Choose antagonists
	CHECK_TICK
	can_continue = can_continue && SSjob.DivideOccupations(mode.required_jobs) 				//Distribute jobs
	CHECK_TICK

	if(!GLOB.Debug2)
		if(!can_continue)
			log_game("[mode.name] failed pre_setup, cause: [mode.setup_error]")
			QDEL_NULL(mode)
			to_chat(world, "<B>Error setting up [GLOB.master_mode].</B> Reverting to pre-game lobby.")
			SSjob.ResetOccupations()
			return FALSE
	else
		message_admins("<span class='notice'>DEBUG: Bypassing prestart checks...</span>")

	CHECK_TICK
	if(hide_mode)
		var/list/modes = new
		for (var/datum/game_mode/M in runnable_modes)
			modes += M.name
		modes = sortList(modes)
		to_chat(world, "<b>The gamemode is: secret!\nPossibilities:</B> [english_list(modes)]")
	else
		mode.announce()

	if(!CONFIG_GET(flag/ooc_during_round))
		toggle_ooc(FALSE) // Turn it off

	CHECK_TICK
	GLOB.start_landmarks_list = shuffle(GLOB.start_landmarks_list) //Shuffle the order of spawn points so they dont always predictably spawn bottom-up and right-to-left
	create_characters() //Create player characters
	collect_minds()
	equip_characters()

	GLOB.data_core.manifest()

	transfer_characters()	//transfer keys to the new mobs

	for(var/I in round_start_events)
		var/datum/callback/cb = I
		cb.InvokeAsync()
	LAZYCLEARLIST(round_start_events)

	log_world("Game start took [(world.timeofday - init_start)/10]s")
	round_start_time = world.time
	SSdbcore.SetRoundStart()

	to_chat(world, "<span class='notice'><B>Welcome to [station_name()], enjoy your stay!</B></span>")
	SEND_SOUND(world, sound(SSstation.announcer.get_rand_welcome_sound()))

	current_state = GAME_STATE_PLAYING
	Master.SetRunLevel(RUNLEVEL_GAME)

	if(SSevents.holidays)
		to_chat(world, "<span class='notice'>and...</span>")
		for(var/holidayname in SSevents.holidays)
			var/datum/holiday/holiday = SSevents.holidays[holidayname]
			to_chat(world, "<h4>[holiday.greet()]</h4>")

	PostSetup()

	return TRUE

/datum/controller/subsystem/ticker/proc/PostSetup()
	set waitfor = FALSE
	mode.post_setup()
	GLOB.start_state = new /datum/station_state()
	GLOB.start_state.count()

	var/list/adm = get_admin_counts()
	var/list/allmins = adm["present"]
	send2adminchat("Server", "Round [GLOB.round_id ? "#[GLOB.round_id]:" : "of"] [hide_mode ? "secret":"[mode.name]"] has started[allmins.len ? ".":" with no active admins online!"]")
	setup_done = TRUE

	for(var/i in GLOB.start_landmarks_list)
		var/obj/effect/landmark/start/S = i
		if(istype(S))							//we can not runtime here. not in this important of a proc.
			S.after_round_start()
		else
			stack_trace("[S] [S.type] found in start landmarks list, which isn't a start landmark!")

	// handle persistence stuff that requires ckeys, in this case hardcore mode and temporal scarring
	for(var/i in GLOB.player_list)
		if(!ishuman(i))
			continue
		var/mob/living/carbon/human/iter_human = i

		iter_human.increment_scar_slot()
		iter_human.load_persistent_scars()

		if(!iter_human.hardcore_survival_score)
			continue
		if(iter_human.mind?.special_role)
			iter_human.hardcore_survival_score *= 2 //Double for antags
		to_chat(iter_human, "<span class='notice'>You will gain [round(iter_human.hardcore_survival_score)] hardcore random points if you survive this round!</span>")

//These callbacks will fire after roundstart key transfer
/datum/controller/subsystem/ticker/proc/OnRoundstart(datum/callback/cb)
	if(!HasRoundStarted())
		LAZYADD(round_start_events, cb)
	else
		cb.InvokeAsync()

//These callbacks will fire before roundend report
/datum/controller/subsystem/ticker/proc/OnRoundend(datum/callback/cb)
	if(current_state >= GAME_STATE_FINISHED)
		cb.InvokeAsync()
	else
		LAZYADD(round_end_events, cb)

/datum/controller/subsystem/ticker/proc/station_explosion_detonation(atom/bomb)
	if(bomb)	//BOOM
		qdel(bomb)

/datum/controller/subsystem/ticker/proc/create_characters()
	for(var/i in GLOB.new_player_list)
		var/mob/dead/new_player/player = i
		if(player.ready == PLAYER_READY_TO_PLAY && player.mind)
			GLOB.joined_player_list += player.ckey
			player.create_character(FALSE)
		else
			player.new_player_panel()
		CHECK_TICK

/datum/controller/subsystem/ticker/proc/collect_minds()
	for(var/i in GLOB.new_player_list)
		var/mob/dead/new_player/P = i
		if(P.new_character && P.new_character.mind)
			SSticker.minds += P.new_character.mind
		CHECK_TICK


/datum/controller/subsystem/ticker/proc/equip_characters()
	var/captainless=1
	for(var/i in GLOB.new_player_list)
		var/mob/dead/new_player/N = i
		var/mob/living/carbon/human/player = N.new_character
		if(istype(player) && player.mind && player.mind.assigned_role)
			if(player.mind.assigned_role == "Captain")
				captainless=0
			if(player.mind.assigned_role != player.mind.special_role)
				SSjob.EquipRank(N, player.mind.assigned_role, 0)
				if(CONFIG_GET(flag/roundstart_traits) && ishuman(N.new_character))
					SSquirks.AssignQuirks(N.new_character, N.client, TRUE)
		CHECK_TICK
	if(captainless)
		for(var/i in GLOB.new_player_list)
			var/mob/dead/new_player/N = i
			if(N.new_character)
				to_chat(N, "<span class='notice'>Captainship not forced on anyone.</span>")
			CHECK_TICK

/datum/controller/subsystem/ticker/proc/transfer_characters()
	var/list/livings = list()
	for(var/i in GLOB.new_player_list)
		var/mob/dead/new_player/player = i
		var/mob/living = player.transfer_character()
		if(living)
			qdel(player)
			living.notransform = TRUE
			if(living.client)
				var/atom/movable/screen/splash/S = new(living.client, TRUE)
				S.Fade(TRUE)
				living.client.init_verbs()
			livings += living
	if(livings.len)
		addtimer(CALLBACK(src, PROC_REF(release_characters), livings), 30, TIMER_CLIENT_TIME)

/datum/controller/subsystem/ticker/proc/release_characters(list/livings)
	for(var/I in livings)
		var/mob/living/L = I
		L.notransform = FALSE

/datum/controller/subsystem/ticker/proc/send_tip_of_the_round()
	var/m
	if(selected_tip)
		m = selected_tip
	else
		var/list/randomtips = world.file2list("strings/tips.txt")
		var/list/memetips = world.file2list("strings/sillytips.txt")
		var/list/abnotips = world.file2list("strings/abnotips.txt")
		var/list/jobtips = world.file2list("strings/jobtips.txt")
		if(abnotips.len && prob(50))	//First, get an abno tip if you can at 50%
			m = pick(abnotips)
		if(randomtips.len && prob(50))	//Then, get a general tip, at 25%
			m = pick(randomtips)
		if(jobtips.len && prob(80))	//Finally, get a job tip, at 20%
			m = pick(jobtips)

		else if(memetips.len)	//at 5% you got the meme tips.
			m = pick(memetips)

	if(m)
		to_chat(world, "<span class='purple'><b>Tip of the round: </b>[html_encode(m)]</span>")

/datum/controller/subsystem/ticker/proc/check_queue()
	if(!queued_players.len)
		return
	var/hpc = CONFIG_GET(number/hard_popcap)
	if(!hpc)
		listclearnulls(queued_players)
		for (var/mob/dead/new_player/NP in queued_players)
			to_chat(NP, "<span class='userdanger'>The alive players limit has been released!<br><a href='byond://?src=[REF(NP)];late_join=override'>[html_encode(">>Join Game<<")]</a></span>")
			SEND_SOUND(NP, sound('sound/misc/notice1.ogg'))
			NP.LateChoices()
		queued_players.len = 0
		queue_delay = 0
		return

	queue_delay++
	var/mob/dead/new_player/next_in_line = queued_players[1]

	switch(queue_delay)
		if(5) //every 5 ticks check if there is a slot available
			listclearnulls(queued_players)
			if(living_player_count() < hpc)
				if(next_in_line?.client)
					to_chat(next_in_line, "<span class='userdanger'>A slot has opened! You have approximately 20 seconds to join. <a href='byond://?src=[REF(next_in_line)];late_join=override'>\>\>Join Game\<\<</a></span>")
					SEND_SOUND(next_in_line, sound('sound/misc/notice1.ogg'))
					next_in_line.LateChoices()
					return
				queued_players -= next_in_line //Client disconnected, remove he
			queue_delay = 0 //No vacancy: restart timer
		if(25 to INFINITY)  //No response from the next in line when a vacancy exists, remove he
			to_chat(next_in_line, "<span class='danger'>No response received. You have been removed from the line.</span>")
			queued_players -= next_in_line
			queue_delay = 0

/datum/controller/subsystem/ticker/proc/check_maprotate()
	if(!CONFIG_GET(flag/maprotation))
		return
	if(world.time - SSticker.round_start_time < 10 MINUTES) //Not forcing map rotation for very short rounds.
		return
	INVOKE_ASYNC(SSmapping, TYPE_PROC_REF(/datum/controller/subsystem/mapping, maprotate))

/datum/controller/subsystem/ticker/proc/HasRoundStarted()
	return current_state >= GAME_STATE_PLAYING

/datum/controller/subsystem/ticker/proc/IsRoundInProgress()
	return current_state == GAME_STATE_PLAYING

/datum/controller/subsystem/ticker/Recover()
	current_state = SSticker.current_state
	force_ending = SSticker.force_ending
	hide_mode = SSticker.hide_mode
	mode = SSticker.mode

	login_music = SSticker.login_music
	round_end_sound = SSticker.round_end_sound

	minds = SSticker.minds

	delay_end = SSticker.delay_end

	anonymousnames = SSticker.anonymousnames
	triai = SSticker.triai
	tipped = SSticker.tipped
	selected_tip = SSticker.selected_tip

	timeLeft = SSticker.timeLeft

	totalPlayers = SSticker.totalPlayers
	totalPlayersReady = SSticker.totalPlayersReady

	queue_delay = SSticker.queue_delay
	queued_players = SSticker.queued_players
	round_start_time = SSticker.round_start_time

	queue_delay = SSticker.queue_delay
	queued_players = SSticker.queued_players

	if (Master) //Set Masters run level if it exists
		switch (current_state)
			if(GAME_STATE_SETTING_UP)
				Master.SetRunLevel(RUNLEVEL_SETUP)
			if(GAME_STATE_PLAYING)
				Master.SetRunLevel(RUNLEVEL_GAME)
			if(GAME_STATE_FINISHED)
				Master.SetRunLevel(RUNLEVEL_POSTGAME)

/datum/controller/subsystem/ticker/proc/send_news_report()
	var/news_message
	var/news_source = "Lobotomy Corporation News"
	switch(news_report)
		if(STATION_EVACUATED)
			var/round_state = "has been successfuly finished"
			if(SSlobotomy_corp.next_ordeal_level < 3)
				round_state = "abruptly ended"
			else if(SSlobotomy_corp.next_ordeal_level < 5 || (istype(SSlobotomy_corp.next_ordeal) && SSlobotomy_corp.next_ordeal.level < 5) || LAZYLEN(SSlobotomy_corp.current_ordeals))
				round_state = "has finished early"

			if(emergency_reason)
				news_message = "A work shift on [station_name()] [round_state] after transmitting the following signal:\n\n[emergency_reason]"
			else
				news_message = "A work shift on [station_name()] [round_state]. No additional data was transmitted."

		if(STATION_DESTROYED_NUKE)
			news_message = "We would like to reassure all personnel that the reports of a nuclear explosion on [station_name()] are, in fact, a hoax. Have a secure day!"

		if(SHUTTLE_HIJACK)
			news_message = "During routine evacuation procedures, the emergency shuttle of [station_name()] had its navigation protocols corrupted and went off course, but was recovered shortly after.\
				[emergency_reason ? "\n\nThe following signal was transmitted upon shift's end: [emergency_reason]" : ""]"

		if(CORE_STARTED)
			news_message = "The employees of [station_name()] attempted a remote core suppression of one of the corporation's sephirots, but did not finish it. Disciplinary actions were taken for wasting company resources.\
				[emergency_reason ? "\n\nThe following signal was transmitted upon shift's end: [emergency_reason]" : ""]"

		if(CORE_SUPPRESSED)
			news_message = "During its daily routine [station_name()] managed to remotely suppress the core of one of the sephirots of the corporation. The employees were rewarded with paid vacation.\
				[emergency_reason ? "\n\nThe following signal was transmitted upon shift's end: [emergency_reason]" : ""]"

		if(CORE_SUPPRESSED_CLAW_DEAD)
			news_message = "The employees of [station_name()] have defeated the manifestation of a Claw, a formidable opponent, during a remote core suppression. We would like to congratulate them for their job\
				[emergency_reason ? "\n\nThe following signal was transmitted upon shift's end: [emergency_reason]" : ""]"

		if(CORE_SUPPRESSED_ARBITER_DEAD)
			news_message = "A reminder that an 'Arbiter' found dead on [station_name()] during remote core suppression was not the real deal and that families of the employees responsible are not in any sort of danger. Have a nice day!\
				[emergency_reason ? "\n\nThe following signal was transmitted upon shift's end: [emergency_reason]" : ""]"

		if(CORE_SUPPRESSED_REDMIST_DEAD)
			news_message = "An entity known as 'Red Mist' that was defeated on [station_name()] is speculated to be a simulation, but nonetheless a very powerful one. All employees were rewarded handsomely for their job.\
				[emergency_reason ? "\n\nThe following signal was transmitted upon shift's end: [emergency_reason]" : ""]"

	if(news_message)
		var/list/payload = list()
		var/network_name = CONFIG_GET(string/cross_comms_network)
		if(network_name)
			payload["network"] = network_name
		send2otherserver(news_source, news_message, "News_Report", additional_data = payload)

/datum/controller/subsystem/ticker/proc/GetTimeLeft()
	if(isnull(SSticker.timeLeft))
		return max(0, start_at - world.time)
	return timeLeft

/datum/controller/subsystem/ticker/proc/SetTimeLeft(newtime)
	if(newtime >= 0 && isnull(timeLeft))	//remember, negative means delayed
		start_at = world.time + newtime
	else
		timeLeft = newtime

//Everyone who wanted to be an observer gets made one now
/datum/controller/subsystem/ticker/proc/create_observers()
	for(var/i in GLOB.new_player_list)
		var/mob/dead/new_player/player = i
		if(player.ready == PLAYER_READY_TO_OBSERVE && player.mind)
			//Break chain since this has a sleep input in it
			addtimer(CALLBACK(player, TYPE_PROC_REF(/mob/dead/new_player, make_me_an_observer)), 1)

/datum/controller/subsystem/ticker/proc/load_mode()
	var/mode = trim(file2text("data/mode.txt"))
	if(mode)
		GLOB.master_mode = mode
	else
		GLOB.master_mode = "extended"
	log_game("Saved mode is '[GLOB.master_mode]'")

/datum/controller/subsystem/ticker/proc/save_mode(the_mode)
	var/F = file("data/mode.txt")
	fdel(F)
	WRITE_FILE(F, the_mode)

/// Returns if either the master mode or the forced secret ruleset matches the mode name.
/datum/controller/subsystem/ticker/proc/is_mode(mode_name)
	return GLOB.master_mode == mode_name || GLOB.secret_force_mode == mode_name

/datum/controller/subsystem/ticker/proc/SetRoundEndSound(the_sound)
	set waitfor = FALSE
	round_end_sound_sent = FALSE
	round_end_sound = fcopy_rsc(the_sound)
	for(var/thing in GLOB.clients)
		var/client/C = thing
		if (!C)
			continue
		C.Export("##action=load_rsc", round_end_sound)
	round_end_sound_sent = TRUE

/datum/controller/subsystem/ticker/proc/Reboot(reason, end_string, delay)
	set waitfor = FALSE
	if(usr && !check_rights(R_SERVER, TRUE))
		return

	if(!delay)
		delay = CONFIG_GET(number/round_end_countdown) * 10

	var/skip_delay = check_rights()
	if(delay_end && !skip_delay)
		to_chat(world, "<span class='boldannounce'>An admin has delayed the round end.</span>")
		return

	to_chat(world, "<span class='boldannounce'>Rebooting World in [DisplayTimeText(delay)]. [reason]</span>")

	var/start_wait = world.time
	UNTIL(round_end_sound_sent || (world.time - start_wait) > (delay * 2))	//don't wait forever
	sleep(delay - (world.time - start_wait))

	if(delay_end && !skip_delay)
		to_chat(world, "<span class='boldannounce'>Reboot was cancelled by an admin.</span>")
		return
	if(end_string)
		end_state = end_string

	var/statspage = CONFIG_GET(string/roundstatsurl)
	var/gamelogloc = CONFIG_GET(string/gamelogurl)
	if(statspage)
		to_chat(world, "<span class='info'>Round statistics and logs can be viewed <a href=\"[statspage][GLOB.round_id]\">at this website!</a></span>")
	else if(gamelogloc)
		to_chat(world, "<span class='info'>Round logs can be located <a href=\"[gamelogloc]\">at this website!</a></span>")

	log_game("<span class='boldannounce'>Rebooting World. [reason]</span>")

	world.Reboot()

/datum/controller/subsystem/ticker/Shutdown()
	gather_newscaster() //called here so we ensure the log is created even upon admin reboot
	save_admin_data()
	update_everything_flag_in_db()
	if(!round_end_sound)
		round_end_sound = pick(\
		'sound/roundend/imaghoul.ogg',
		'sound/roundend/newroundsexy.ogg',
		'sound/roundend/apcdestroyed.ogg',
		'sound/roundend/bangindonk.ogg',
		'sound/roundend/leavingtg.ogg',
		'sound/roundend/its_only_game.ogg',
		'sound/roundend/bannedonfulpstation.ogg',
		'sound/roundend/yeehaw.ogg',
		'sound/roundend/disappointed.ogg',
		'sound/roundend/scrunglartiy.ogg',
		'sound/roundend/petersondisappointed.ogg',
		'sound/abnormalities/nothingthere/goodbye_cast.ogg'\
		)
	///The reference to the end of round sound that we have chosen.
	var/sound/end_of_round_sound_ref = sound(round_end_sound)
	for(var/mob/M in GLOB.player_list)
		if(M.client.prefs?.toggles & SOUND_ENDOFROUND)
			SEND_SOUND(M.client, end_of_round_sound_ref)

	text2file(login_music, "data/last_round_lobby_music.txt")

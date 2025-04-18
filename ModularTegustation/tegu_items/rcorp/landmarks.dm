GLOBAL_LIST_INIT(easycombat, list(
	/mob/living/simple_animal/hostile/abnormality/blue_shepherd,
	/mob/living/simple_animal/hostile/abnormality/helper,
	/mob/living/simple_animal/hostile/abnormality/smile,
	/mob/living/simple_animal/hostile/abnormality/pinocchio,
	/mob/living/simple_animal/hostile/abnormality/fragment,
	/mob/living/simple_animal/hostile/abnormality/fairy_gentleman,
	/mob/living/simple_animal/hostile/abnormality/drifting_fox,
	/mob/living/simple_animal/hostile/abnormality/headless_ichthys,
	/mob/living/simple_animal/hostile/abnormality/puss_in_boots,
	/mob/living/simple_animal/hostile/abnormality/woodsman,
))

GLOBAL_LIST_INIT(easysupport, list(
	/mob/living/simple_animal/hostile/abnormality/funeral,
	/mob/living/simple_animal/hostile/abnormality/pisc_mermaid,
	/mob/living/simple_animal/hostile/abnormality/redblooded,
	/mob/living/simple_animal/hostile/abnormality/wayward,
	/mob/living/simple_animal/hostile/abnormality/ppodae,
	/mob/living/simple_animal/hostile/abnormality/apex_predator,
	/mob/living/simple_animal/hostile/abnormality/cleaner,
	/mob/living/simple_animal/hostile/abnormality/der_freischutz,
	/mob/living/simple_animal/hostile/abnormality/better_memories,
))

GLOBAL_LIST_INIT(easytank, list(
	/mob/living/simple_animal/hostile/abnormality/jangsan,
	/mob/living/simple_animal/hostile/abnormality/scarecrow,
	/mob/living/simple_animal/hostile/abnormality/kqe,
	/mob/living/simple_animal/hostile/abnormality/warden,
	/mob/living/simple_animal/hostile/abnormality/golden_apple,
	/mob/living/simple_animal/hostile/abnormality/porccubus,
	/mob/living/simple_animal/hostile/abnormality/black_swan,
))

GLOBAL_LIST_INIT(hardcombat, list(
	/mob/living/simple_animal/hostile/abnormality/clouded_monk,
	/mob/living/simple_animal/hostile/abnormality/clown,
	/mob/living/simple_animal/hostile/abnormality/nosferatu,
	/mob/living/simple_animal/hostile/abnormality/big_wolf,
	/mob/living/simple_animal/hostile/abnormality/luna,
	/mob/living/simple_animal/hostile/abnormality/red_hood,
))

GLOBAL_LIST_INIT(hardsupport, list(/mob/living/simple_animal/hostile/abnormality/sphinx,
	/mob/living/simple_animal/hostile/abnormality/ebony_queen,
	/mob/living/simple_animal/hostile/abnormality/thunder_bird,
	/mob/living/simple_animal/hostile/abnormality/despair_knight,
	/mob/living/simple_animal/hostile/abnormality/yin,
	/mob/living/simple_animal/hostile/abnormality/pygmalion,
	/mob/living/simple_animal/hostile/abnormality/big_bird,
))

GLOBAL_LIST_INIT(hardtank, list(/mob/living/simple_animal/hostile/abnormality/melting_love,
	/mob/living/simple_animal/hostile/abnormality/nothing_there,
	/mob/living/simple_animal/hostile/abnormality/censored,
	/mob/living/simple_animal/hostile/abnormality/titania,
	/mob/living/simple_animal/hostile/abnormality/greed_king,
	/mob/living/simple_animal/hostile/abnormality/eris,
	/mob/living/simple_animal/hostile/abnormality/general_b,
))

GLOBAL_LIST_INIT(rhinobuster, list(,
	/mob/living/simple_animal/hostile/abnormality/dimensional_refraction,
	/mob/living/simple_animal/hostile/abnormality/rudolta,
	/mob/living/simple_animal/hostile/abnormality/judgement_bird,
	/mob/living/simple_animal/hostile/abnormality/alriune,
	/mob/living/simple_animal/hostile/abnormality/fire_bird,
))

//Used for the specific raidboss mode
GLOBAL_LIST_INIT(raidboss, list(/mob/living/simple_animal/hostile/distortion/shrimp_rambo/easy,
	/mob/living/simple_animal/hostile/abnormality/mountain,
	/mob/living/simple_animal/hostile/ordeal/black_fixer,
))


//Split into 3 groups, Combat for damaging abnos, Support for ranged, AOE and otherwise support abnos, and tank for abnos that can take a beating reliably
/obj/effect/landmark/abnospawn/easycombat
	name = "easy combat abno spawner"
	desc = "It spawns an abno. Notify a coder. Thanks!"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "x4"

/obj/effect/landmark/abnospawn/easycombat/Initialize()
	..()
	var/spawning = pick_n_take(GLOB.easycombat)
	var/mob/living/simple_animal/hostile/abnormality/A = new spawning(get_turf(src))
	A.rcorp_team = "easy"
	return INITIALIZE_HINT_QDEL

/obj/effect/landmark/abnospawn/easysupport
	name = "easy support abno spawner"
	desc = "It spawns an abno. Notify a coder. Thanks!"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "x3"

/obj/effect/landmark/abnospawn/easysupport/Initialize()
	..()
	var/spawning = pick_n_take(GLOB.easysupport)
	var/mob/living/simple_animal/hostile/abnormality/A = new spawning(get_turf(src))
	A.rcorp_team = "easy"
	return INITIALIZE_HINT_QDEL

/obj/effect/landmark/abnospawn/easytank
	name = "easy tank abno spawner"
	desc = "It spawns an abno. Notify a coder. Thanks!"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "x2"

/obj/effect/landmark/abnospawn/easytank/Initialize()
	..()
	var/spawning = pick_n_take(GLOB.easytank)
	var/mob/living/simple_animal/hostile/abnormality/A = new spawning(get_turf(src))
	A.rcorp_team = "easy"
	return INITIALIZE_HINT_QDEL

/obj/effect/landmark/abnospawn/hardcombat
	name = "hard combat abno spawner"
	desc = "It spawns an abno. Notify a coder. Thanks!"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "x4"

/obj/effect/landmark/abnospawn/hardcombat/Initialize()
	..()
	var/spawning = pick_n_take(GLOB.hardcombat)
	new spawning(get_turf(src))
	return INITIALIZE_HINT_QDEL


/obj/effect/landmark/abnospawn/hardsupport
	name = "hard support abno spawner"
	desc = "It spawns an abno. Notify a coder. Thanks!"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "x3"

/obj/effect/landmark/abnospawn/hardsupport/Initialize()
	..()
	var/spawning = pick_n_take(GLOB.hardsupport)
	new spawning(get_turf(src))
	return INITIALIZE_HINT_QDEL


/obj/effect/landmark/abnospawn/hardtank
	name = "hard tank abno spawner"
	desc = "It spawns an abno. Notify a coder. Thanks!"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "x2"

/obj/effect/landmark/abnospawn/hardtank/Initialize()
	..()
	var/spawning = pick_n_take(GLOB.hardtank)
	new spawning(get_turf(src))
	return INITIALIZE_HINT_QDEL


/obj/effect/landmark/abnospawn/rhinobuster
	name = "hard tank abno spawner"
	desc = "It spawns an abno. Notify a coder. Thanks!"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "tdome_admin"

/obj/effect/landmark/abnospawn/rhinobuster/Initialize()
	..()
	var/spawning = pick_n_take(GLOB.rhinobuster)
	new spawning(get_turf(src))
	return INITIALIZE_HINT_QDEL

/obj/effect/landmark/abnospawn/raidboss
	name = "raidboss spawner"
	desc = "It spawns an abno. Notify a coder. Thanks!"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "x2"

/obj/effect/landmark/abnospawn/raidboss/Initialize()
	..()
	var/spawning = pick_n_take(GLOB.raidboss)
	new spawning(get_turf(src))
	return INITIALIZE_HINT_QDEL

//To do: Deshit this.

/obj/effect/landmark/nobasic_incorp_move
	name = "incorp barrier"
	desc = "no basic incorp move"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "x2"

/obj/effect/landmark/nobasic_incorp_move/Initialize()
	..()
	var/turf/T = get_turf(src)
	T.turf_flags |= NO_BASIC_INCORP_MOVE
	return INITIALIZE_HINT_LATELOAD

/obj/effect/landmark/nobasic_incorp_move/Destroy()
	var/turf/T = get_turf(src)
	T.turf_flags &= ~NO_BASIC_INCORP_MOVE
	. = ..()

/obj/effect/landmark/nobasic_incorp_move/disappearing
	name = "disappearing incorp barrier"
	desc = "no basic incorp move"

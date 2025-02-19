/obj/machinery/atmospherics/trinary/filter
	icon = 'icons/obj/atmospherics/filter.dmi'
	icon_state = "hintact_off"
	name = "Gas filter"
	default_colour = "#b70000"
	mirror = /obj/machinery/atmospherics/trinary/filter/mirrored

	var/on = 0
	var/temp = null // -- TLE

	var/target_pressure = ONE_ATMOSPHERE

	var/filter_type = 0
/*
Filter types:
-1: Nothing
 0: Plasma: Plasma Toxin, Oxygen Agent B
 1: Oxygen: Oxygen ONLY
 2: Nitrogen: Nitrogen ONLY
 3: Carbon Dioxide: Carbon Dioxide ONLY
 4: Sleeping Agent (N2O)
*/

	frequency = 0
	var/datum/radio_frequency/radio_connection

	ex_node_offset = 5

/obj/machinery/atmospherics/trinary/filter/set_frequency(new_frequency)
	radio_controller.remove_object(src, frequency)
	frequency = new_frequency
	if(frequency)
		radio_connection = radio_controller.add_object(src, frequency, RADIO_ATMOSIA)

/obj/machinery/atmospherics/trinary/filter/New()
	if(ticker && ticker.current_state == GAME_STATE_PLAYING)
		initialize()
	..()

/obj/machinery/atmospherics/trinary/filter/update_icon()
	if(stat & NOPOWER)
		icon_state = "hintact_off"
	else if(stat & FORCEDISABLE)
		icon_state = "hintact_malflocked"
	else if(node2 && node3 && node1)
		icon_state = "hintact_[on?("on"):("off")]"
	else
		icon_state = "hintact_off"
		on = 0
	..()

/obj/machinery/atmospherics/trinary/filter/power_change()
	var/old_stat = stat
	..()
	if(old_stat != stat)
		on = !on
		update_icon()

/obj/machinery/atmospherics/trinary/filter/process()
	. = ..()
	if(!on)
		return

	var/output_starting_pressure = air3.return_pressure()
	var/pressure_delta = target_pressure - output_starting_pressure
	var/filtered_pressure_delta = target_pressure - air2.return_pressure()

	if(pressure_delta > 0.01 && filtered_pressure_delta > 0.01 && (air1.temperature > 0 || air3.temperature > 0))
		//Figure out how much gas to transfer to meet the target pressure.
		var/air_temperature = (air1.temperature > 0) ? air1.temperature : air3.temperature
		var/output_volume = air3.volume + (network3 ? network3.volume : 0)
		//get the number of moles that would have to be transfered to bring sink to the target pressure
		var/transfer_moles = (pressure_delta * output_volume) / (air_temperature * R_IDEAL_GAS_EQUATION)
		var/datum/gas_mixture/removed = air1.remove(transfer_moles)

		if(!removed)
			return
		var/datum/gas_mixture/filtered_out = new
		filtered_out.temperature = removed.temperature

		#define FILTER(g) filtered_out.adjust_gas((g), removed[g])
		switch(filter_type)
			if(0) //removing hydrocarbons
				FILTER(GAS_PLASMA)
				FILTER(GAS_OXAGENT)

			if(1) //removing O2
				FILTER(GAS_OXYGEN)

			if(2) //removing N2
				FILTER(GAS_NITROGEN)

			if(3) //removing CO2
				FILTER(GAS_CARBON)

			if(4)//removing N2O
				FILTER(GAS_SLEEPING)

		removed.subtract(filtered_out)
		#undef FILTER

		air2.merge(filtered_out)
		air3.merge(removed)

		if(network2)
			network2.update = 1
		if(network3)
			network3.update = 1
		if(network1)
			network1.update = 1

	return 1

/obj/machinery/atmospherics/trinary/filter/initialize()
	if (!radio_controller)
		return
	set_frequency(frequency)
	..()


/obj/machinery/atmospherics/trinary/filter/attack_hand(user as mob) // -- TLE
	if(..())
		return

	if(!src.allowed(user))
		to_chat(user, "<span class='warning'>Access denied.</span>")
		return

	var/dat
	var/current_filter_type
	switch(filter_type)
		if(0)
			current_filter_type = "Plasma"
		if(1)
			current_filter_type = "Oxygen"
		if(2)
			current_filter_type = "Nitrogen"
		if(3)
			current_filter_type = "Carbon Dioxide"
		if(4)
			current_filter_type = "Nitrous Oxide"
		if(-1)
			current_filter_type = "Nothing"
		else
			current_filter_type = "ERROR - Report this bug to the admin, please!"

	dat += {"
			<b>Power: </b><a href='?src=\ref[src];power=1'>[on?"On":"Off"]</a><br>
			<b>Filtering: </b>[current_filter_type]<br><HR>
			<h4>Set Filter Type:</h4>
			<A href='?src=\ref[src];filterset=0'>Plasma</A><BR>
			<A href='?src=\ref[src];filterset=1'>Oxygen</A><BR>
			<A href='?src=\ref[src];filterset=2'>Nitrogen</A><BR>
			<A href='?src=\ref[src];filterset=3'>Carbon Dioxide</A><BR>
			<A href='?src=\ref[src];filterset=4'>Nitrous Oxide</A><BR>
			<A href='?src=\ref[src];filterset=-1'>Nothing</A><BR>
			<HR><B>Desirable output pressure:</B>
			[src.target_pressure]kPa | <a href='?src=\ref[src];set_press=1'>Change</a>
			"}
/*
		user << browse("<HEAD><TITLE>[src.name] control</TITLE></HEAD>[dat]","window=atmo_filter")
		onclose(user, "atmo_filter")
		return

	if (src.temp)
		dat = text("<TT>[]</TT><BR><BR><A href='?src=\ref[];temp=1'>Clear Screen</A>", src.temp, src)
	//else
	//	src.on != src.on
*/
	user << browse("<HEAD><TITLE>[src.name] control</TITLE></HEAD><TT>[dat]</TT>", "window=atmo_filter")
	onclose(user, "atmo_filter")
	return

/obj/machinery/atmospherics/trinary/filter/Topic(href, href_list) // -- TLE
	if(..())
		return
	usr.set_machine(src)
	src.add_fingerprint(usr)
	if(href_list["filterset"])
		src.filter_type = text2num(href_list["filterset"])
	if (href_list["temp"])
		src.temp = null
	if(href_list["set_press"])
		var/new_pressure = input(usr,"Enter new output pressure (0-4500kPa)","Pressure control",src.target_pressure) as num
		src.target_pressure = max(0, min(4500, new_pressure))
	if(href_list["power"])
		on=!on
	src.update_icon()
	src.updateUsrDialog()
/*
	for(var/mob/M in viewers(1, src))
		if ((M.client && M.machine == src))
			src.attack_hand(M)
*/
	return


/obj/machinery/atmospherics/trinary/filter/mirrored
	icon_state = "hintactm_off"
	pipe_flags = IS_MIRROR

/obj/machinery/atmospherics/trinary/filter/mirrored/update_icon(var/adjacent_procd)
	..(adjacent_procd)
	if(stat & NOPOWER)
		icon_state = "hintactm_off"
	else if(stat & FORCEDISABLE)
		icon_state = "hintactm_malflocked"
	else if(!(node2 && node3 && node1))
		on = 0
	icon_state = "hintactm_[on?("on"):("off")]"

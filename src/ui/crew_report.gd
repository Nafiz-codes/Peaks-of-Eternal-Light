extends RefCounted
## Read-only specialist reports from the authoritative mission state.
const ROLES := {
	"power_console": ["Energy specialist", "203a72", "I monitor solar generation, consumption, and our stored power."],
	"water_recycler": ["Water specialist", "79c8df", "I monitor our water reserve and the recycler's recovery each sol."],
	"food_storage": ["Food specialist", "b5d878", "I monitor food reserves, crew consumption, and supply decisions."],
	"crew_briefing": ["Crew lead", "b7a2ff", "I coordinate mission decisions and track oxygen, crew stress, and radiation exposure."]
}

static func relevant(id: String, event: Dictionary) -> bool:
	if id == "crew_briefing":
		return true
	var terms: Array = {"power_console": ["power", "solar_array", "battery"], "water_recycler": ["water", "recycl"], "food_storage": ["food", "ration"]}.get(id, [])
	var description := JSON.stringify(event).to_lower()
	for term in terms:
		if term in description:
			return true
	return false

static func build(id: String, state: Variant, catalog: Array = []) -> Dictionary:
	if not ROLES.has(id):
		return {}
	var report := {"role": ROLES[id][0], "color": Color(ROLES[id][1]), "task": ROLES[id][2], "update": "", "status": "Awaiting mission", "decisions": [], "effects": [], "terminal": false}
	if state == null:
		report.update = "Ready when you are, Commander. Start the mission to receive my first operational report."
	else:
		report.terminal = state.mission_outcome.get("status", "") != "in_progress"
		report.status = "Sol %02d / %d · %s" % [state.sol, state.mission_length_sols, str(state.mission_outcome.get("status", "")).replace("_", " ")]
		match id:
			"power_console":
				report.update = "We have %.2f kWh in reserve. Last sol we generated %.2f kWh and used %.2f kWh, for a balance of %+.2f kWh." % [state.power_kwh, state.power_generated_kwh, state.power_consumed_kwh, state.power_balance_kwh]
				if state.consecutive_power_depleted_sols > 0:
					report.update += " Power has been depleted for %d consecutive sol(s). Two consecutive depleted sols end the mission." % state.consecutive_power_depleted_sols
				elif state.power_balance_kwh < 0:
					report.update += " We used more than we generated last sol. Keep an eye on the reserve."
			"water_recycler":
				report.update = "Our water reserve is %.2f L. Last sol the crew used %.2f L and we recovered %.2f L. Water status: %s." % [state.water_l, state.water_consumed_l, state.water_recovered_l, state.life_support_status.get("water", "unavailable")]
			"food_storage":
				report.update = "We have %.2f kg of food. The crew consumed %.2f kg last sol. Food status: %s." % [state.food_kg, state.food_consumed_kg, state.life_support_status.get("food", "unavailable")]
			"crew_briefing":
				report.update = "We have %d crew, %.2f kg of oxygen (%s), and average crew stress of %.2f. Accumulated modeled radiation dose is %.3f mSv. There are %d decisions awaiting your orders." % [state.crew_size, state.oxygen_kg, state.life_support_status.get("oxygen", "unavailable"), state.crew_stress_avg, state.radiation_msv, state.pending_events.size()]
		if state.sol == 0:
			report.update += " This is our initial inventory; no sol has run yet."
		if report.terminal:
			report.update += " The mission has ended. Review the mission report for the final outcome."
			if state.mission_outcome.get("status") == "failure":
				report.update += " Reason: " + str(state.mission_outcome.get("failure_reason", "")).replace("_", " ") + "."
		else:
			for event in state.pending_events:
				if relevant(id, event):
					report.decisions.append(event.duplicate(true))
		for active in state.active_events:
			var definition: Dictionary = active
			for event in catalog:
				if event.get("event_id") == active.get("event_id"):
					definition = event
					break
			if relevant(id, definition):
				report.effects.append("%s · %d sol(s) remaining" % [str(active.get("event_id", "Effect")).replace("_", " "), int(active.get("remaining_sols", 0))])
	# Full displayed content identifies an update, including a new sol or decision.
	report.signature = JSON.stringify([report.status, report.update, report.decisions, report.effects])
	return report

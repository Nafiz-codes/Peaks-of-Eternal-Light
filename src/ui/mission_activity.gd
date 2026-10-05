extends RefCounted

## Shared read-only formatting. No interpretation of effect formulas.
static func describe(state: Variant, events: Array) -> String:
	if state == null:
		return "Start a mission to see activity."
	var lines := PackedStringArray()
	lines.append("Pending decisions: %d" % state.pending_events.size())
	for active in state.active_events:
		lines.append("Active: %s / %d sol(s) remaining" % [str(active.get("event_id", "")).replace("_", " "), int(active.get("remaining_sols", 0))])
	for resolved in state.resolved_events:
		var choice_text := str(resolved.get("choice_id", "Acknowledged")).replace("_", " ")
		for event in events:
			if event.get("event_id") != resolved.get("event_id"):
				continue
			var choices: Variant = event.get("choices")
			if not choices is Array:
				continue
			for choice in choices:
				if choice.get("choice_id") == resolved.get("choice_id"):
					choice_text = str(choice.get("text", choice_text))
		lines.append("Sol %d / %s\n%s" % [int(resolved.get("sol", 0)), str(resolved.get("event_id", "")).replace("_", " "), choice_text])
	if state.resolved_events.is_empty():
		lines.append("No resolved decisions yet.")
	return "\n\n".join(lines)

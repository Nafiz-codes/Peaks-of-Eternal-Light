extends Node

## Small runtime bridge between the landing selector and the walkable outpost.
## It carries selection only; MissionSimulator remains authoritative for mission
## resources, ticks, actions, and outcomes.

var selected_site_id := ""

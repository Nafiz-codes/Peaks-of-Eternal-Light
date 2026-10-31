extends SceneTree
const Planner = preload("res://src/simulation/mission_planner.gd")
const Save = preload("res://src/runtime/mission_save.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var planner := Planner.new()
	var session := root.get_node("MissionSession")
	var signals := {"count":0}
	session.mission_plan_approved.connect(func(_record: Dictionary): signals.count += 1)
	for site in planner.simulator.sites:
		var p := planner.default_plan(site.site_id)
		var result := planner.evaluate(p)
		print("DEFAULT %s: %s margin %.2f" % [site.site_id,result.errors,result.margin_kwh])
		check(result.valid,"Every site has a viable default: " + site.site_id)
		check(planner.zones(site.site_id).size()==3,"Three zones")
		var distributed := p.duplicate(true)
		distributed.solar_placement = "extended"
		var spread := planner.evaluate(distributed)
		check(spread.generated_kwh<result.generated_kwh and spread.materials_required>result.materials_required,"Distributed placement has paid cable/material tradeoffs")
		var dim := []
		dim.resize(168)
		dim.fill(0.015)
		planner.yield_cache["%s:168" % site.site_id] = dim
		var marginal := p.duplicate(true)
		marginal.cargo.battery = 1
		check(planner.evaluate(marginal).status=="Limited margin","Reserve distinguishes limited but viable margin")
		planner.yield_cache.clear()
		var altered := p.duplicate(true)
		altered.zone_id = "south"
		check(planner.evaluate(altered).transport.distance_m!=result.transport.distance_m,"Zone updates route")
		check(not planner.set_quantity(p,"supplies",0),"Mandatory cargo locked")
		check(not planner.set_quantity(p,"battery",20),"Overcapacity addition blocked")
		altered = p.duplicate(true)
		altered.cargo.battery = -1
		check(not planner.evaluate(altered).valid,"Negative quantities rejected")
		altered.cargo.battery = NAN
		check(not planner.evaluate(altered).valid,"Nonfinite quantities rejected")
		altered = p.duplicate(true)
		altered.cargo.battery = 20
		check(not planner.evaluate(altered).valid,"Overcapacity approval blocked")
		altered = p.duplicate(true)
		altered.cargo.supplies = 0
		check(not planner.evaluate(altered).valid,"Missing survival cargo rejected")
		altered = p.duplicate(true)
		altered.hours = 336
		altered.cargo.battery = 0
		altered.cargo.array = 0
		var dark := []
		dark.resize(336)
		dark.fill(0.0)
		planner.yield_cache["%s:336" % site.site_id] = dark
		check(not planner.evaluate(altered).valid,"Insufficient survival power rejected")
		planner.yield_cache.clear()
		altered = p.duplicate(true)
		altered.zone_id = "unknown"
		check(not planner.evaluate(altered).valid,"Unknown zone rejected")
		check(planner.route(p,result.cargo_units*2).energy_kwh>result.transport.energy_kwh,"Load affects energy")
		altered = p.duplicate(true)
		altered.cargo.handling = 1
		check(planner.route(altered,result.cargo_units).energy_kwh<result.transport.energy_kwh,"Handling reduces trips")
		altered = p.duplicate(true)
		altered.route_id = "east_detour"
		check(planner.route(altered,result.cargo_units).distance_m>result.transport.distance_m,"Detour changes distance")
		altered.deployment_id = "east"
		if site.site_id=="plateau_d": check(not planner.evaluate(altered).valid,"Unsafe terrain route rejected")
		var yields := planner._yields(site.site_id,24)
		var mean := 0.0
		for value in yields: mean += value/24.0
		check(is_equal_approx(mean,planner.Solar.daily_fraction(site,0,true)),"Hourly power matches authoritative daily solar quadrature")
		session.select_landing_site(site.site_id)
		session.begin_planning()
		var before := Save.state_data(session.dashboard_state)
		var previous_count: int = signals.count
		check(session.approve_planning().valid,"Valid approval")
		check(session.approve_planning().valid,"Idempotent approval")
		check(signals.count==previous_count+1,"Only one approval event per identical plan")
		var pending: Dictionary = session.pending_mission_plan()
		pending.plan.cargo.battery = 0
		check(session.approved_plan.plan.cargo.battery==2,"Handoff data is an isolated copy")
		check(Save.state_data(session.dashboard_state)==before,"Approval never delivers inventory")
		var data := Save.capture(session)
		check(Save.write_file("user://planner-test.save",data)==OK,"Disk save")
		check(Save.restore(session,Save.read_file("user://planner-test.save"))==OK,"Disk restore")
		check(session.approved_plan.get("plan",{}).get("site_id")==site.site_id,"Approved site retained")
		data.approved_plan.plan.cargo.supplies = 0
		check(Save.decode(data).is_empty(),"Corrupt approval rejected")
		data = Save.capture(session)
		data.approved_plan.plan_id = "tampered"
		check(Save.decode(data).is_empty(),"Corrupt handoff identity rejected")
		var legacy := Save.capture(session)
		legacy.version = 3
		legacy.erase("planning_draft")
		legacy.erase("approved_plan")
		check(not Save.decode(legacy).is_empty(),"Legacy save compatibility")
	session.start_selected_mission()
	var existing := Save.state_data(session.dashboard_state)
	session.begin_planning()
	session.approve_planning()
	check(Save.state_data(session.dashboard_state)==existing,"Opening/reapproving preserves established inventory")
	check(planner.evaluate({}).valid==false,"Empty corrupt plan is safe")
	print("MISSION PLANNER: %d failures" % failures)
	quit(failures)

extends SceneTree
const Rules = preload("res://src/simulation/rover_expedition.gd")
var failures := 0
var assertions := 0
func check(value: bool, message: String):
	assertions += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize():
	var d := Rules.fresh()
	check(Rules.valid_save(d),"Fresh save valid")
	for sol in range(2): check(Rules.assigned(d,sol) == -1,"Future operation locked")
	check(Rules.assigned(d,2) == 0,"Survey unlocks Sol 2")
	check(Rules.assigned(d,6) == 0,"Overdue operation retained")
	d.completed.append(0)
	check(Rules.assigned(d,3) == -1,"Frozen Horizon locked before Sol 4")
	check(Rules.assigned(d,4) == 1,"Frozen Horizon unlocks Sol 4")
	d.completed.append(1)
	check(Rules.assigned(d,5) == -1,"Lifeline locked before Sol 6")
	check(Rules.assigned(d,6) == 2,"Lifeline unlocks Sol 6")
	d.mission = 2
	d.discovered = true
	d.stabilized = true
	check(not Rules.ready_to_return(d),"Cannot extract before restoring communications")
	d.relay = true
	check(Rules.ready_to_return(d),"Rescue objectives permit extraction check")
	d.route.append(Vector3(INF,0,0))
	check(not Rules.valid_save(d),"Reject nonfinite escort path")
	d = Rules.fresh()
	d.completed = [0,0]
	check(not Rules.valid_save(d),"Reject duplicate completion")
	d = Rules.fresh()
	d.phase = "returning"
	check(not Rules.valid_save(d),"Reject premature return save")
	var old := preload("res://src/simulation/rover_training.gd").new()
	old.begin(0)
	old.record_scan("alpha")
	check(Rules.migrate(old.data).surveys == ["alpha"],"Old survey progress retained")
	old.begin(2)
	check(Rules.migrate(old.data).completed == [0,1],"Earlier training completions retained")
	print("EXPEDITION RULES: %d failures / %d assertions" % [failures,assertions])
	quit(1 if failures else 0)

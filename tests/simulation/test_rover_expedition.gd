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
	# Operations follow story order, not the sol count (days were replaced by Earth time).
	check(Rules.assigned(d) == 0,"Surface Survey comes first")
	d.completed.append(0)
	check(Rules.assigned(d) == 1,"Frozen Horizon follows the survey")
	d.completed.append(1)
	check(Rules.assigned(d) == 2,"Lifeline follows Frozen Horizon")
	d.completed.append(2)
	check(Rules.assigned(d) == -1,"Nothing is assigned after all three")
	d.completed = [0,1]
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

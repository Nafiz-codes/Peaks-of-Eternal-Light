extends SceneTree

const CHARACTER_PATH := "res://Meshy_AI_Golden_Visor_Explorer_0926090109_texture.glb"


func _init() -> void:
	var packed_scene := load(CHARACTER_PATH) as PackedScene
	if packed_scene == null:
		push_error("Could not load %s" % CHARACTER_PATH)
		quit(1)
		return

	var character := packed_scene.instantiate()
	var summary := {
		"nodes": 0,
		"mesh_instances": 0,
		"skeletons": 0,
		"animation_players": 0,
		"animations": []
	}
	_collect(character, summary)
	print(JSON.stringify(summary))
	character.queue_free()
	quit(0)


func _collect(node: Node, summary: Dictionary) -> void:
	summary["nodes"] += 1
	if node is MeshInstance3D:
		summary["mesh_instances"] += 1
	if node is Skeleton3D:
		summary["skeletons"] += 1
	if node is AnimationPlayer:
		summary["animation_players"] += 1
		for animation_name in node.get_animation_list():
			summary["animations"].append(str(animation_name))
	for child in node.get_children():
		_collect(child, summary)

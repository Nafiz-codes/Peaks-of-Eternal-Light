extends RefCounted
static func fit(model: Node3D, extent: float) -> void:
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (model.global_transform.affine_inverse()*node.global_transform)*node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first: return
	var factor := extent / maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
	model.scale *= factor
	model.position += Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*factor

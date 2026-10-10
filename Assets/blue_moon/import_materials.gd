@tool
extends EditorScenePostImport

## The FBX uses Maya material names; the supplied PNGs use matching T_ prefixes.
func _post_import(scene: Node) -> Object:
	var materials: Dictionary = {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		for index in node.mesh.get_surface_count():
			var source: Material = node.mesh.surface_get_material(index)
			if source == null:
				continue
			var material_name := source.resource_name
			var prefix := "res://Assets/blue_moon/Textures/T_" + material_name
			if not ResourceLoader.exists(prefix + "_BaseColor.png"):
				continue # Preserve the author's untextured utility materials.
			if not materials.has(material_name):
				var material := StandardMaterial3D.new()
				material.resource_name = material_name
				material.albedo_texture = load(prefix + "_BaseColor.png")
				material.normal_enabled = true
				material.normal_texture = load(prefix + "_Normal.png")
				var orm: Texture2D = load(prefix + "_ORM.png")
				material.ao_enabled = true
				material.ao_texture = orm
				material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				material.roughness_texture = orm
				material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
				material.metallic = 1.0
				material.metallic_texture = orm
				material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
				materials[material_name] = material
			node.mesh.surface_set_material(index, materials[material_name])
	return scene

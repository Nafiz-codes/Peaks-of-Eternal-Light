extends RefCounted
## One canonical identity; portraits always resolve inside the selected appearance.
const CREW_ID := "CREW_01"
const NAME_LIMIT := 32
const ASSETS := "res://Resources/characters/preparation/assets.json"
const EXPRESSIONS := "res://Resources/characters/preparation/expressions.json"
static var asset_catalog: Dictionary = {}
static var expression_catalog: Dictionary = {}

static func _load_catalogs() -> void:
	if asset_catalog.is_empty():
		asset_catalog = JSON.parse_string(FileAccess.get_file_as_string(ASSETS))
		expression_catalog = JSON.parse_string(FileAccess.get_file_as_string(EXPRESSIONS))

static func options() -> Array[Dictionary]:
	_load_catalogs()
	var result: Array[Dictionary] = []
	for variant in asset_catalog.get("variants", []):
		if variant.character_id == CREW_ID and not asset_path(variant.full_body_asset_id).is_empty() and not frame(variant.variant_id, "frame_00").is_empty():
			result.append(variant)
	return result

static func asset_path(id: String) -> String:
	_load_catalogs()
	for asset in asset_catalog.get("assets", []):
		if asset.asset_id == id and asset.character_id == CREW_ID:
			return asset.path if ResourceLoader.exists(asset.path) else ""
	return ""

static func valid_appearance(id: String) -> bool:
	for option in options():
		if option.variant_id == id: return true
	return false

static func name_error(value: String) -> String:
	var clean := value.strip_edges()
	if clean.is_empty(): return "Enter your Commander's name to continue."
	if clean.length() > NAME_LIMIT: return "Use %d characters or fewer." % NAME_LIMIT
	for i in clean.length():
		var code := clean.unicode_at(i)
		if code < 32 or code == 127 or code in [0x200B, 0x200E, 0x200F, 0xFEFF] or (code >= 0x202A and code <= 0x202E) or (code >= 0x2066 and code <= 0x2069):
			return "Use a name without hidden formatting or control characters."
	return ""

static func create(appearance: String, player_name: String) -> Dictionary:
	if not valid_appearance(appearance) or not name_error(player_name).is_empty(): return {}
	return {"crew_id": CREW_ID, "role": "commander", "name": player_name.strip_edges(),
		"appearance_id": appearance, "customization": {}}

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	# Legacy saves deliberately have no invented name or portrait.
	if value.is_empty(): return true
	return value.get("crew_id") == CREW_ID and value.get("role") == "commander" and value.get("name") is String and name_error(value.name).is_empty() and value.name == value.name.strip_edges() and value.get("appearance_id") is String and valid_appearance(value.appearance_id) and value.get("customization", {}) is Dictionary

static func frame(appearance: String, request := "neutral") -> Dictionary:
	_load_catalogs()
	var baseline: Dictionary = {}
	for entry in expression_catalog.get("frames", []):
		if entry.character_id != CREW_ID or entry.variant_id != appearance: continue
		if entry.frame_index == 0: baseline = entry
		# Frame IDs are exact authoring references. Emotion aliases only use supported labels.
		if entry.expression_id == CREW_ID + ":" + appearance + ":" + request:
			return entry.duplicate(true)
		if entry.suggested_emotion == request and entry.emotion_status == "visually_supported":
			return entry.duplicate(true)
	return baseline.duplicate(true)

static func portrait(identity: Dictionary, expression := "neutral") -> Dictionary:
	if identity.is_empty() or not valid(identity): return {}
	return frame(identity.appearance_id, expression)

static func texture_for_frame(entry: Dictionary) -> AtlasTexture:
	if entry.is_empty(): return null
	var texture := AtlasTexture.new()
	texture.atlas = load(entry.asset_path)
	var rect: Array = entry.rect_px
	# Trim grid rules at render time; originals remain byte-for-byte unchanged.
	texture.region = Rect2(rect[0] + 4, rect[1] + 4, rect[2] - 8, rect[3] - 8)
	return texture

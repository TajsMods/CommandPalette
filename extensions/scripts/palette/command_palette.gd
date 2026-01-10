# ==============================================================================
# Command Palette - Core Settings
# Author: TajemnikTV
# Description: Core-managed command palette configuration/state
# ==============================================================================
class_name TajsCoreCommandPalette
extends RefCounted

const SETTINGS_KEY := "core.command_palette"
const LEGACY_SETTINGS_KEY := "command_palette.config"
const CORE_DEBUG_KEY := "core.debug"

const PALETTE_DEFAULTS := {
	"hotkey": "middle_mouse",
	"favorites": [],
	"recents": [],
	"tools_enabled": false,
	"max_recents": 10,
	"palette_onboarded": false,
	"tab_autocomplete": true
}

static func get_default_config() -> Dictionary:
	return {
		"command_palette_enabled": true,
		"wire_drop_menu_enabled": true,
		"right_click_clear_enabled": true,
		"select_all_enabled": true,
		"goto_group_enabled": true,
		"buy_max_enabled": true,
		"z_order_fix_enabled": true,
		"six_input_containers": true,
		"mute_on_focus_loss": true,
		"custom_boot_screen": true,
		"highlight_disconnected_enabled": true,
		"extra_glow": false,
		"ui_opacity": 100.0,
		"palette": PALETTE_DEFAULTS.duplicate(true)
	}

var _settings
var _logger
var _config: Dictionary = {}


func setup(settings, logger = null) -> void:
	_settings = settings
	_logger = logger
	_register_schema()
	_load_config()


func _register_schema() -> void:
	if _settings != null and _settings.has_method("register_schema"):
		_settings.register_schema("core", {
			SETTINGS_KEY: {
				"type": "dict",
				"default": get_default_config(),
				"description": "Command palette configuration/state"
			}
		})


func _load_config() -> void:
	if _settings == null:
		_config = get_default_config()
		return
	var stored: Dictionary = _settings.get_dict(SETTINGS_KEY, {})
	if stored.is_empty():
		var legacy: Dictionary = _settings.get_dict(LEGACY_SETTINGS_KEY, {})
		if legacy is Dictionary and not legacy.is_empty():
			stored = legacy
			_settings.set_value(SETTINGS_KEY, stored)
			_log_info("Migrated legacy command palette settings.")
	_config = _merge_config(stored)
	_migrate_legacy_keys()
	_maybe_migrate_legacy_palette_file()
	_save_if_missing()


func _merge_config(stored: Dictionary) -> Dictionary:
	var merged: Dictionary = get_default_config()
	for key in stored.keys():
		if key == "palette" and stored[key] is Dictionary:
			var palette := PALETTE_DEFAULTS.duplicate(true)
			for p_key in stored[key].keys():
				palette[p_key] = stored[key][p_key]
			merged["palette"] = palette
		else:
			merged[key] = stored[key]
	return merged


func _migrate_legacy_keys() -> void:
	if _config.has("palette_tools_enabled"):
		var palette = _config.get("palette", {})
		if palette is Dictionary and not palette.has("tools_enabled"):
			palette["tools_enabled"] = _config["palette_tools_enabled"]
			_config["palette"] = palette
		_config.erase("palette_tools_enabled")
		save_config()


func _maybe_migrate_legacy_palette_file() -> void:
	if not FileAccess.file_exists("user://tajs_mod_palette.json"):
		return
	var palette = _config.get("palette", {})
	if _palette_has_user_data(palette):
		return
	var file = FileAccess.open("user://tajs_mod_palette.json", FileAccess.READ)
	if file == null:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	var data = json.get_data()
	file.close()
	if not (data is Dictionary):
		return
	var merged := PALETTE_DEFAULTS.duplicate(true)
	for key in data.keys():
		merged[key] = data[key]
	_config["palette"] = merged
	save_config()
	_log_info("Migrated legacy palette file to core settings.")


func _palette_has_user_data(palette: Dictionary) -> bool:
	if palette.is_empty():
		return false
	if palette.get("favorites", []).size() > 0:
		return true
	if palette.get("recents", []).size() > 0:
		return true
	if palette.get("tools_enabled", false):
		return true
	if palette.get("palette_onboarded", false):
		return true
	if palette.get("hotkey", "") != PALETTE_DEFAULTS.get("hotkey", "middle_mouse"):
		return true
	if palette.get("tab_autocomplete", true) != PALETTE_DEFAULTS.get("tab_autocomplete", true):
		return true
	return false


func _save_if_missing() -> void:
	var changed := false
	var defaults := get_default_config()
	for key in defaults.keys():
		if not _config.has(key):
			_config[key] = defaults[key]
			changed = true
	var palette = _config.get("palette", {})
	if not (palette is Dictionary):
		palette = {}
	for key in PALETTE_DEFAULTS.keys():
		if not palette.has(key):
			palette[key] = PALETTE_DEFAULTS[key]
			changed = true
	_config["palette"] = palette
	if changed:
		save_config()


func save_config() -> void:
	if _settings != null and _settings.has_method("set_value"):
		_settings.set_value(SETTINGS_KEY, _config)


func get_value(key: String, default_override = null):
	if key == "debug_mode":
		if _settings != null and _settings.has_method("get_bool"):
			return _settings.get_bool(CORE_DEBUG_KEY, false)
	if _config.has(key):
		return _config[key]
	var palette = _config.get("palette", {})
	if palette is Dictionary and palette.has(key):
		return palette[key]
	if default_override != null:
		return default_override
	var defaults := get_default_config()
	if defaults.has(key):
		return defaults[key]
	if PALETTE_DEFAULTS.has(key):
		return PALETTE_DEFAULTS[key]
	return null


func set_value(key: String, value) -> void:
	if key == "debug_mode":
		if _settings != null and _settings.has_method("set_value"):
			_settings.set_value(CORE_DEBUG_KEY, bool(value))
		return
	if key == "palette" and value is Dictionary:
		_config["palette"] = value
		save_config()
		return
	if get_default_config().has(key):
		_config[key] = value
		save_config()
		return
	if PALETTE_DEFAULTS.has(key):
		var palette = _config.get("palette", {})
		if not (palette is Dictionary):
			palette = {}
		palette[key] = value
		_config["palette"] = palette
		save_config()
		return
	_config[key] = value
	save_config()


func reset_to_defaults() -> void:
	_config = get_default_config()
	save_config()
	_log_info("Command palette settings reset to defaults.")


func is_enabled() -> bool:
	return bool(get_value("command_palette_enabled", true))


func set_enabled(enabled: bool) -> void:
	set_value("command_palette_enabled", enabled)


func get_palette() -> Dictionary:
	return _config.get("palette", PALETTE_DEFAULTS.duplicate(true))


func get_favorites() -> Array:
	var palette = get_palette()
	return palette.get("favorites", []).duplicate()


func is_favorite(command_id: String) -> bool:
	return command_id in get_favorites()


func add_favorite(command_id: String) -> void:
	var palette = get_palette()
	var favorites = palette.get("favorites", [])
	if command_id not in favorites:
		favorites.append(command_id)
		palette["favorites"] = favorites
		_config["palette"] = palette
		save_config()


func remove_favorite(command_id: String) -> void:
	var palette = get_palette()
	var favorites = palette.get("favorites", [])
	favorites.erase(command_id)
	palette["favorites"] = favorites
	_config["palette"] = palette
	save_config()


func toggle_favorite(command_id: String) -> bool:
	if is_favorite(command_id):
		remove_favorite(command_id)
		return false
	add_favorite(command_id)
	return true


func get_recents() -> Array:
	var palette = get_palette()
	return palette.get("recents", []).duplicate()


func add_recent(command_id: String) -> void:
	var palette = get_palette()
	var recents = palette.get("recents", [])
	recents.erase(command_id)
	recents.push_front(command_id)
	var max_recents = palette.get("max_recents", 10)
	if recents.size() > max_recents:
		recents.resize(max_recents)
	palette["recents"] = recents
	_config["palette"] = palette
	save_config()


func clear_recents() -> void:
	var palette = get_palette()
	palette["recents"] = []
	_config["palette"] = palette
	save_config()


func are_tools_enabled() -> bool:
	var palette = get_palette()
	return palette.get("tools_enabled", false)


func set_tools_enabled(enabled: bool) -> void:
	var palette = get_palette()
	palette["tools_enabled"] = enabled
	_config["palette"] = palette
	save_config()


func is_onboarded() -> bool:
	var palette = get_palette()
	return palette.get("palette_onboarded", false)


func set_onboarded(value: bool) -> void:
	var palette = get_palette()
	palette["palette_onboarded"] = value
	_config["palette"] = palette
	save_config()


func _log_info(message: String) -> void:
	if _logger != null and _logger.has_method("info"):
		_logger.info("core", message)

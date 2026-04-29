class_name TajsCoreCommandPalette
extends RefCounted

const MODULE_ID := "TajemnikTV-CommandPalette"
const SETTINGS_KEY := "core.command_palette"
const LEGACY_SETTINGS_KEY := "command_palette.config"
const CORE_DEBUG_KEY := "core.debug"
const MIGRATION_NS := "tajs_command_palette_storage_split"

const PALETTE_DEFAULTS := {
    "hotkey": "middle_mouse",
    "tools_enabled": true,
    "max_recents": 10,
    "tab_autocomplete": true
}

static func get_default_config() -> Dictionary:
    return {
        "command_palette_enabled": true,
        "palette": PALETTE_DEFAULTS.duplicate(true)
    }

var _settings
var _logger
var _core
var _storage
var _config: Dictionary = {}
var _state_recents: Array = []
var _state_favorites: Array = []
var _state_onboarded: bool = false

func setup(settings, logger = null) -> void:
    _settings = settings
    _logger = logger
    _core = Engine.get_meta("TajsCore", null)
    _storage = _core.storage if _core != null else null
    if _settings != null and _settings.has_signal("value_changed"):
        if not _settings.value_changed.is_connected(_on_setting_changed):
            _settings.value_changed.connect(_on_setting_changed)
    _register_schema()
    _load_config()
    _load_state()
    _migrate_legacy_if_needed()
    _save_all()

func _register_schema() -> void:
    if _settings != null and _settings.has_method("register_schema"):
        _settings.register_schema(MODULE_ID, {
            MODULE_ID + ".max_recents": {
                "type": "int",
                "default": 10,
                "description": "Maximum number of recent commands"
            }
        })

func _load_config() -> void:
    if _storage == null:
        _config = get_default_config()
        return
    var config_path = _storage.get_config_path(MODULE_ID)
    var data = _storage.read_json(config_path, {})
    var values: Dictionary = {}
    if data is Dictionary:
        values = data.get("values", {})
    _config = _merge_config(values)

func _load_state() -> void:
    _state_recents = _read_state_array("recents.json")
    _state_favorites = _read_state_array("favorites.json")
    _state_onboarded = bool(_read_state_value("onboarding.json", false))

func _migrate_legacy_if_needed() -> void:
    if _settings == null:
        return
    if _settings.get_migration_version(MIGRATION_NS) != "0.0.0":
        return
    var legacy: Dictionary = _settings.get_dict(SETTINGS_KEY, {})
    if legacy.is_empty():
        legacy = _settings.get_dict(LEGACY_SETTINGS_KEY, {})
    if legacy.has("palette") and legacy["palette"] is Dictionary:
        var palette: Dictionary = legacy["palette"]
        _state_recents = palette.get("recents", [])
        _state_favorites = palette.get("favorites", [])
        _state_onboarded = bool(palette.get("palette_onboarded", false))
        var cfg_palette = _config.get("palette", {})
        cfg_palette["hotkey"] = palette.get("hotkey", cfg_palette.get("hotkey", "middle_mouse"))
        cfg_palette["tools_enabled"] = palette.get("tools_enabled", cfg_palette.get("tools_enabled", true))
        cfg_palette["max_recents"] = palette.get("max_recents", cfg_palette.get("max_recents", 10))
        cfg_palette["tab_autocomplete"] = palette.get("tab_autocomplete", cfg_palette.get("tab_autocomplete", true))
        _config["palette"] = cfg_palette
    if legacy.has("command_palette_enabled"):
        _config["command_palette_enabled"] = bool(legacy["command_palette_enabled"])
    _settings.set_migration_version(MIGRATION_NS, "1.0.0")

func _save_all() -> void:
    _save_config()
    _write_state_array("recents.json", _state_recents, "recents")
    _write_state_array("favorites.json", _state_favorites, "favorites")
    _write_state_value("onboarding.json", _state_onboarded, "onboarding")

func _save_config() -> void:
    if _storage == null:
        return
    var payload = {
        "meta": _storage.make_meta(MODULE_ID, "config"),
        "values": _config
    }
    _storage.write_json(_storage.get_config_path(MODULE_ID), payload, true)

func _merge_config(stored: Dictionary) -> Dictionary:
    var merged: Dictionary = get_default_config()
    for key in stored.keys():
        if key == "palette" and stored[key] is Dictionary:
            var palette = PALETTE_DEFAULTS.duplicate(true)
            for p_key in stored[key].keys():
                if p_key in ["recents", "favorites", "palette_onboarded"]:
                    continue
                palette[p_key] = stored[key][p_key]
            merged["palette"] = palette
        else:
            merged[key] = stored[key]
    return merged

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
    var defaults = get_default_config()
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
        var filtered = value.duplicate(true)
        filtered.erase("recents")
        filtered.erase("favorites")
        filtered.erase("palette_onboarded")
        _config["palette"] = filtered
        _save_config()
        return
    if get_default_config().has(key):
        _config[key] = value
        _save_config()
        return
    if PALETTE_DEFAULTS.has(key):
        var palette = _config.get("palette", {})
        if not (palette is Dictionary):
            palette = {}
        palette[key] = value
        _config["palette"] = palette
        _save_config()
        return
    _config[key] = value
    _save_config()

func _on_setting_changed(key: String, value, _old) -> void:
    if key == "TajemnikTV-CommandPalette.max_recents" and str(value).is_valid_int():
        _enforce_recents_limit(int(value))

func _enforce_recents_limit(limit: int) -> void:
    if _state_recents.size() > limit:
        _state_recents.resize(limit)
        _write_state_array("recents.json", _state_recents, "recents")

func reset_to_defaults() -> void:
    _config = get_default_config()
    _save_config()

func is_enabled() -> bool:
    return bool(get_value("command_palette_enabled", true))

func set_enabled(enabled: bool) -> void:
    set_value("command_palette_enabled", enabled)

func get_favorites() -> Array:
    return _state_favorites.duplicate()

func is_favorite(command_id: String) -> bool:
    return command_id in _state_favorites

func add_favorite(command_id: String) -> void:
    if command_id not in _state_favorites:
        _state_favorites.append(command_id)
        _write_state_array("favorites.json", _state_favorites, "favorites")

func remove_favorite(command_id: String) -> void:
    _state_favorites.erase(command_id)
    _write_state_array("favorites.json", _state_favorites, "favorites")

func toggle_favorite(command_id: String) -> bool:
    if is_favorite(command_id):
        remove_favorite(command_id)
        return false
    add_favorite(command_id)
    return true

func get_recents() -> Array:
    return _state_recents.duplicate()

func add_recent(command_id: String) -> void:
    _state_recents.erase(command_id)
    _state_recents.push_front(command_id)
    var max_recents = 10
    if _settings != null and _settings.has_method("get_int"):
        max_recents = _settings.get_int("TajemnikTV-CommandPalette.max_recents", 10)
    else:
        max_recents = int(get_value("max_recents", 10))
    if _state_recents.size() > max_recents:
        _state_recents.resize(max_recents)
    _write_state_array("recents.json", _state_recents, "recents")

func clear_recents() -> void:
    _state_recents = []
    _write_state_array("recents.json", _state_recents, "recents")

func are_tools_enabled() -> bool:
    return bool(get_value("tools_enabled", false))

func set_tools_enabled(enabled: bool) -> void:
    set_value("tools_enabled", enabled)

func is_onboarded() -> bool:
    return _state_onboarded

func set_onboarded(value: bool) -> void:
    _state_onboarded = value
    _write_state_value("onboarding.json", _state_onboarded, "onboarding")

func _read_state_array(file_name: String) -> Array:
    var payload = _read_state_payload(file_name)
    var items: Variant = payload.get("items", [])
    if items is Array:
        return items.duplicate(true)
    return []

func _read_state_value(file_name: String, default_value: Variant) -> Variant:
    var payload = _read_state_payload(file_name)
    return payload.get("items", default_value)

func _write_state_array(file_name: String, items: Array, kind: String) -> void:
    _write_state_payload(file_name, items.duplicate(true), kind)

func _write_state_value(file_name: String, item: Variant, kind: String) -> void:
    _write_state_payload(file_name, item, kind)

func _read_state_payload(file_name: String) -> Dictionary:
    if _storage == null:
        return {"meta": _default_meta(file_name.trim_suffix(".json")), "items": []}
    var path = _storage.get_state_path(MODULE_ID, file_name)
    var payload = _storage.read_json(path, {})
    if not (payload is Dictionary):
        payload = {}
    if not payload.has("meta"):
        payload["meta"] = _default_meta(file_name.trim_suffix(".json"))
    if not payload.has("items"):
        payload["items"] = []
    return payload

func _write_state_payload(file_name: String, items: Variant, kind: String) -> void:
    if _storage == null:
        return
    var payload = {"meta": _default_meta(kind), "items": items}
    _storage.write_json(_storage.get_state_path(MODULE_ID, file_name), payload, true)

func _default_meta(kind: String) -> Dictionary:
    if _storage != null and _storage.has_method("make_meta"):
        return _storage.make_meta(MODULE_ID, kind)
    return {"schema_version": "1.0.0", "module": MODULE_ID, "kind": kind}

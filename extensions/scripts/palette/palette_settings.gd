# ==============================================================================
# Command Palette - Settings Wrapper
# Description: Thin wrapper over Core command palette settings
# ==============================================================================
class_name TajsCommandPaletteSettings
extends RefCounted

const LOG_NAME := "PaletteSettings"
const SETTINGS_KEY := "core.command_palette"
const CoreLog = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/common/core_log.gd")
const CorePaletteScript = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/command_palette.gd")

var _palette


func setup(settings = null, core = null) -> void:
    if core == null:
        core = _get_core()
    if core != null and core.command_palette != null:
        _palette = core.command_palette
        return
    if settings != null and CorePaletteScript != null:
        _palette = CorePaletteScript.new()
        var logger = core.logger if core != null else null
        _palette.setup(settings, logger)
        if core != null and core.command_palette == null:
            core.command_palette = _palette
        return
    _log_warn("Command palette settings unavailable.")


func get_value(key: String, default_override = null):
    return _call("get_value", [key, default_override], default_override)


func set_value(key: String, value) -> void:
    _call("set_value", [key, value])


func reset_to_defaults() -> void:
    _call("reset_to_defaults")


func is_enabled() -> bool:
    return bool(_call("is_enabled", [], true))


func set_enabled(enabled: bool) -> void:
    _call("set_enabled", [enabled])


func get_favorites() -> Array:
    return _call("get_favorites", [], [])


func is_favorite(command_id: String) -> bool:
    return bool(_call("is_favorite", [command_id], false))


func add_favorite(command_id: String) -> void:
    _call("add_favorite", [command_id])


func remove_favorite(command_id: String) -> void:
    _call("remove_favorite", [command_id])


func toggle_favorite(command_id: String) -> bool:
    return bool(_call("toggle_favorite", [command_id], false))


func get_recents() -> Array:
    return _call("get_recents", [], [])


func add_recent(command_id: String) -> void:
    _call("add_recent", [command_id])


func clear_recents() -> void:
    _call("clear_recents")


func are_tools_enabled() -> bool:
    return bool(_call("are_tools_enabled", [], false))


func set_tools_enabled(enabled: bool) -> void:
    _call("set_tools_enabled", [enabled])


func is_onboarded() -> bool:
    return bool(_call("is_onboarded", [], false))


func set_onboarded(value: bool) -> void:
    _call("set_onboarded", [value])


func _call(method: String, args: Array = [], default_value = null):
    if _palette != null and _palette.has_method(method):
        return _palette.callv(method, args)
    return default_value


func _get_core():
    if Engine.has_meta("TajsCore"):
        var core = Engine.get_meta("TajsCore")
        if core != null and core.has_method("require"):
            return core
    return null


func _log_warn(message: String) -> void:
    CoreLog.log_warn(LOG_NAME, message)

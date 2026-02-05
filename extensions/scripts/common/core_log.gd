# ==============================================================================
# Command Palette - Core Logging Helper
# Description: Routes logging through Core when available
# ==============================================================================
extends RefCounted

const CORE_META_KEY := "TajsCore"
const MODULE_ID := "TajemnikTV-CommandPalette"

static func _get_core():
    if Engine.has_meta(CORE_META_KEY):
        var core = Engine.get_meta(CORE_META_KEY)
        if core != null and core.has_method("logi"):
            return core
    return null

static func _format(source: String, message: String) -> String:
    if source == "":
        return message
    return "%s %s" % [source, message]

static func log_info(source: String, message: String) -> void:
    var core = _get_core()
    var text := _format(source, message)
    if core != null:
        core.logi(MODULE_ID, text)
    else:
        print(text)

static func log_warn(source: String, message: String) -> void:
    var core = _get_core()
    var text := _format(source, message)
    if core != null:
        core.logw(MODULE_ID, text)
    else:
        print(text)

static func log_error(source: String, message: String) -> void:
    var core = _get_core()
    var text := _format(source, message)
    if core != null:
        core.loge(MODULE_ID, text)
    else:
        print(text)

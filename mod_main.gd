extends Node

const MOD_ID := "TajemnikTV-CommandPalette"
const LOG_NAME := "Main"
const CORE_META_KEY := "TajsCore"
const CORE_MIN_VERSION := "1.0.0"
const KEYBIND_CATEGORY_ID := "tajs_command_palette"

const PaletteControllerScript = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/palette_controller.gd")
const PaletteSettingsScript = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/palette_settings.gd")
const CoreLog = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/common/core_log.gd")

var _core
var _config
var palette_controller
var _palette_initialized: bool = false


func _init() -> void:
    _core = _get_core()
    if _core == null:
        _log_warn("Taj's Core not found; Command Palette disabled.")
        return
    if not _core.require(CORE_MIN_VERSION):
        _log_warn("Taj's Core %s+ required; Command Palette disabled." % CORE_MIN_VERSION)
        return
    _register_module()
    _register_settings()
    _setup_settings()
    _init_controller()
    _register_keybinds()
    _register_events()


func _get_core():
    if Engine.has_meta(CORE_META_KEY):
        var core = Engine.get_meta(CORE_META_KEY)
        if core != null and core.has_method("require"):
            return core
    return null


func _register_module() -> void:
    if _core.has_method("register_module"):
        _core.register_module({
            "id": MOD_ID,
            "name": "Command Palette",
            "version": "1.0.0",
            "min_core_version": CORE_MIN_VERSION
        })


func _register_settings() -> void:
    if _core.settings == null:
        return
    _core.settings.register_schema(MOD_ID, {
        MOD_ID + ".max_recents": {
            "type": "int",
            "default": 10,
            "description": "Max Recent Commands"
        }
    })


func _setup_settings() -> void:
    _config = PaletteSettingsScript.new()
    _config.setup(_core.settings, _core)
    if _config == null:
        _log_warn("Command palette settings unavailable.")


func _init_controller() -> void:
    palette_controller = PaletteControllerScript.new()
    palette_controller.name = "PaletteController"
    add_child(palette_controller)


func _register_events() -> void:
    if _core.event_bus != null:
        _core.event_bus.on("game.hud_ready", Callable(self , "_on_hud_ready"), self , true)
    call_deferred("_check_existing_hud")


func _check_existing_hud() -> void:
    if _palette_initialized:
        return
    var root = get_tree().root if get_tree() != null else null
    if root == null:
        return
    var hud = root.get_node_or_null("Main/HUD")
    if hud != null:
        _on_hud_ready({})


func _on_hud_ready(_payload: Dictionary) -> void:
    if _palette_initialized:
        return
    if palette_controller == null or _core == null:
        return
    if _config == null:
        _log_warn("Command palette settings unavailable; palette UI disabled.")
        return
    var registry = _core.commands if _core.commands != null else _core.command_registry
    if registry == null:
        _log_warn("Command registry not available; palette UI disabled.")
        return
    palette_controller.initialize(get_tree(), _config, null, self , registry)
    _palette_initialized = true
    if _core.event_bus != null:
        _core.event_bus.emit("command_palette.ready", {"controller": palette_controller, "overlay": palette_controller.overlay}, true)


func _register_keybinds() -> void:
    if _core.keybinds == null:
        return
    _core.keybinds.register_keybind_category(KEYBIND_CATEGORY_ID, "Command Palette", "res://textures/icons/palette.png")

    var toggle_event = _core.keybinds.make_mouse_event(MOUSE_BUTTON_MIDDLE)
    _core.keybinds.register_action_scoped(
        MOD_ID,
        "toggle",
        "Open Command Palette",
        [toggle_event],
        _core.keybinds.CONTEXT_NO_TEXT,
        Callable(self , "_on_palette_toggle"),
        10,
        KEYBIND_CATEGORY_ID,
        true
    )

    var back_event = _core.keybinds.make_mouse_event(MOUSE_BUTTON_XBUTTON1)
    _core.keybinds.register_action_scoped(
        MOD_ID,
        "back",
        "Palette Back",
        [back_event],
        _core.keybinds.CONTEXT_ANY,
        Callable(self , "_on_palette_back"),
        0,
        KEYBIND_CATEGORY_ID
    )

    var forward_event = _core.keybinds.make_mouse_event(MOUSE_BUTTON_XBUTTON2)
    _core.keybinds.register_action_scoped(
        MOD_ID,
        "forward",
        "Palette Forward",
        [forward_event],
        _core.keybinds.CONTEXT_ANY,
        Callable(self , "_on_palette_forward"),
        0,
        KEYBIND_CATEGORY_ID
    )

    var favorite_event = _core.keybinds.make_key_event(KEY_F, true)
    _core.keybinds.register_action_scoped(
        MOD_ID,
        "favorite_selected",
        "Favorite Selected",
        [favorite_event],
        _core.keybinds.CONTEXT_ANY,
        Callable(self , "_on_palette_favorite"),
        0,
        KEYBIND_CATEGORY_ID
    )


func _on_palette_toggle() -> void:
    if palette_controller == null or _config == null:
        return
    if not _config.get_value("command_palette_enabled", true):
        return
    palette_controller.toggle()


func _on_palette_back() -> void:
    if palette_controller and palette_controller.is_open() and palette_controller.overlay:
        palette_controller.overlay._go_back()


func _on_palette_forward() -> void:
    if palette_controller and palette_controller.is_open() and palette_controller.overlay:
        palette_controller.overlay._go_forward()


func _on_palette_favorite() -> void:
    if palette_controller and palette_controller.is_open():
        palette_controller.toggle_favorite_selected()


func _log_info(message: String) -> void:
    if _core != null and _core.has_method("logi"):
        _core.logi(MOD_ID, message)
    else:
        CoreLog.log_info(LOG_NAME, message)


func _log_warn(message: String) -> void:
    if _core != null and _core.has_method("logw"):
        _core.logw(MOD_ID, message)
    else:
        CoreLog.log_warn(LOG_NAME, message)

extends Node

const MOD_ID := "TajemnikTV-CommandPalette"
const LOG_NAME := "TajemnikTV-CommandPalette:Main"
const CORE_META_KEY := "TajsCore"
const CORE_MIN_VERSION := "1.0.0"
const KEYBIND_CATEGORY_ID := "tajs_command_palette"
const SETTINGS_PREFIX := "tajs_command_palette"
const SETTING_MAX_RECENTS := SETTINGS_PREFIX + ".max_recents"
const LEGACY_SETTING_MAX_RECENTS := MOD_ID + ".max_recents"

const PaletteControllerScript = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/palette_controller.gd")
const PaletteSettingsScript = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/palette_settings.gd")

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


func _ready() -> void:
    if _core == null:
        return
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
            "version": _get_mod_version(),
            "min_core_version": CORE_MIN_VERSION
        })


func _register_settings() -> void:
    var settings = _get_settings_service()
    if settings == null:
        return
    var schema := {
        SETTING_MAX_RECENTS: {
            "type": "int",
            "default": 10,
            "label": "Max Recent Commands",
            "description": "Max Recent Commands"
        }
    }
    if _core.has_method("register_settings_schema"):
        _core.register_settings_schema(MOD_ID, schema)
    _migrate_legacy_setting_keys()

func _migrate_legacy_setting_keys() -> void:
    var settings = _get_settings_service()
    if _core == null or settings == null:
        return
    var migration_ns := "tajs_command_palette_naming"
    if settings.get_migration_version(migration_ns) != "0.0.0":
        return
    if settings.get_value(SETTING_MAX_RECENTS, null) == null:
        var legacy = settings.get_value(LEGACY_SETTING_MAX_RECENTS, null)
        if legacy != null:
            settings.set_value(SETTING_MAX_RECENTS, legacy)
    settings.set_migration_version(migration_ns, "1.0.0")


func _setup_settings() -> void:
    _config = PaletteSettingsScript.new()
    _config.setup(_get_settings_service(), _core)
    if _config == null:
        _log_warn("Command palette settings unavailable.")


func _init_controller() -> void:
    palette_controller = PaletteControllerScript.new()
    palette_controller.name = "PaletteController"
    add_child(palette_controller)


func _register_events() -> void:
    var event_bus = _get_event_bus()
    if event_bus != null:
        event_bus.on("game.hud_ready", Callable(self , "_on_hud_ready"), self , true)
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
    var registry = _get_command_registry()
    if registry == null:
        _log_warn("Command registry not available; palette UI disabled.")
        return
    palette_controller.initialize(get_tree(), _config, null, self , registry)
    _palette_initialized = true
    var event_bus = _get_event_bus()
    if event_bus != null:
        event_bus.emit("command_palette.ready", {"controller": palette_controller, "overlay": palette_controller.overlay}, true)

func _get_settings_service() -> Variant:
    if _core == null:
        return null
    if _core.has_method("get_settings_service"):
        return _core.get_settings_service()
    return _core.settings

func _get_event_bus() -> Variant:
    if _core == null:
        return null
    if _core.has_method("get_event_bus"):
        return _core.get_event_bus()
    return _core.event_bus

func _get_command_registry() -> Variant:
    if _core == null:
        return null
    if _core.has_method("get_command_registry"):
        return _core.get_command_registry()
    return _core.commands


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
    elif _has_global_class("ModLoaderLog"):
        ModLoaderLog.info(message, MOD_ID)
    else:
        print("%s %s" % [MOD_ID, message])


func _log_warn(message: String) -> void:
    if _core != null and _core.has_method("logw"):
        _core.logw(MOD_ID, message)
    elif _has_global_class("ModLoaderLog"):
        ModLoaderLog.warning(message, MOD_ID)
    else:
        print("%s %s" % [MOD_ID, message])

func _get_mod_version() -> String:
    var manifest_path = get_script().resource_path.get_base_dir().path_join("manifest.json")
    if FileAccess.file_exists(manifest_path):
        var file := FileAccess.open(manifest_path, FileAccess.READ)
        if file:
            var json := JSON.new()
            if json.parse(file.get_as_text()) == OK:
                var data = json.get_data()
                if data is Dictionary and data.has("version_number"):
                    return str(data["version_number"])
    return "0.1.0"

static func _has_global_class(class_name_str: String) -> bool:
    for entry in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false

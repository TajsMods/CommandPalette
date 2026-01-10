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
var wire_colors

# Optional services that other mods can attach to
var undo_manager
var wire_clear_handler
var focus_handler
var node_group_z_fix
var disconnected_highlighter
var sticky_note_manager
var goto_group_manager


func _init() -> void:
	_core = _get_core()
	if _core == null:
		_log_warn("Taj's Core not found; Command Palette disabled.")
		return
	if not _core.require(CORE_MIN_VERSION):
		_log_warn("Taj's Core %s+ required; Command Palette disabled." % CORE_MIN_VERSION)
		return
	_register_module()
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
		_core.event_bus.on("game.hud_ready", Callable(self, "_on_hud_ready"), self, true)


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
	palette_controller.initialize(get_tree(), _config, null, self, registry)
	_palette_initialized = true


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
		Callable(self, "_on_palette_toggle"),
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
		Callable(self, "_on_palette_back"),
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
		Callable(self, "_on_palette_forward"),
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


func sync_settings_toggle(_config_key: String) -> void:
	pass


func _set_goto_group_visible(_visible: bool) -> void:
	pass


func _set_buy_max_visible(_visible: bool) -> void:
	pass


func set_extra_glow(_enabled: bool) -> void:
	pass


func _apply_ui_opacity(value: float) -> void:
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		var hud = main.get_node_or_null("HUD")
		if hud:
			var main_container = hud.get_node_or_null("Main/MainContainer")
			if main_container:
				main_container.modulate.a = value / 100.0


func _debug_log_wrapper(message: String, force: bool = false) -> void:
	if force or (_config != null and _config.get_value("debug_mode", false)):
		_log_info(message)

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

class_name TajsCommandPalettePaletteController
extends Node

const LOG_NAME = "Controller"

# Script references
const ContextProviderScript = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/context_provider.gd")
const PaletteOverlayScript = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/palette_overlay.gd")
const DefaultCommandsScript = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/default_commands.gd")

# Shared helpers
const NodeCompatibilityFilterScript = preload("res://mods-unpacked/TajemnikTV-Core/core/nodes/node_compatibility_filter.gd")
const CoreServices = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/common/core_services.gd")
const NodeMetadataServiceScript = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/node_metadata_service.gd")

# Components
var registry: RefCounted # TajsCoreCommandRegistry
var context: RefCounted # TajsCommandPaletteContextProvider
var palette_config: RefCounted # TajsCoreCommandPalette
var overlay: CanvasLayer # TajsCommandPalettePaletteOverlay

var node_filter # TajsCommandPaletteNodeCompatibilityFilter

# External references
var mod_config # TajsCommandPaletteSettings

# State
var _initialized: bool = false
var _palette_enabled: bool = true # Can be toggled via settings

signal palette_opened
signal palette_closed
signal command_executed(command_id: String)

func _log(message: String, is_error: bool = false) -> void:
    var mod_id := "TajemnikTV-CommandPalette"
    if is_error:
        if Engine.has_meta("TajsCore"):
            var core = Engine.get_meta("TajsCore")
            if core != null and core.has_method("loge"):
                core.loge(mod_id, message)
                return
        if _has_global_class("ModLoaderLog"):
            ModLoaderLog.error(message, LOG_NAME)
        else:
            print("%s %s" % [LOG_NAME, message])
    else:
        if Engine.has_meta("TajsCore"):
            var core = Engine.get_meta("TajsCore")
            if core != null and core.has_method("logi"):
                core.logi(mod_id, message)
                return
        if _has_global_class("ModLoaderLog"):
            ModLoaderLog.info(message, LOG_NAME)
        else:
            print("%s %s" % [LOG_NAME, message])


func _init() -> void:
    name = "PaletteController"


func _ready() -> void:
    pass


## Initialize the palette system
func initialize(tree: SceneTree, config, _ui = null, _mod_main_ref = null, registry_ref = null) -> void:
    if _initialized:
        return

    mod_config = config
    registry = registry_ref

    if registry == null:
        _log("Command registry not available; palette disabled.", true)
        return

    # Initialize palette enabled state from config
    _palette_enabled = mod_config.get_value("command_palette_enabled", true) if mod_config else true

    # Create core components
    context = ContextProviderScript.new()
    palette_config = mod_config

    # Set up context
    context.set_tree(tree)
    if mod_config:
        context.set_config(mod_config)

    # Initialize node filter EARLY so metadata service can use it
    node_filter = NodeCompatibilityFilterScript.new()
    # Defer cache building to not block startup
    call_deferred("_build_node_filter_cache")

    # Initialize metadata service (MUST be before overlay setup)
    _init_node_metadata_service()

    # Create overlay
    overlay = PaletteOverlayScript.new()
    tree.root.call_deferred("add_child", overlay)
    overlay.setup(registry, context, palette_config, node_metadata_service, null)

    # Register default commands
    _register_default_commands()

    _initialized = true
    _log("Palette system initialized with %d commands" % registry.get_count())


# Node Metadata Service
var node_metadata_service # TajsCommandPaletteNodeMetadataService instance

func _init_node_metadata_service() -> void:
    # Shared metadata service script
    node_metadata_service = NodeMetadataServiceScript.new()
    _log("Node metadata service initialized (Shared Script)")


## Get the node metadata service
func get_node_metadata_service() -> RefCounted:
    return node_metadata_service


## Clear metadata cache (used when wire colors change)
func clear_metadata_cache() -> void:
    if node_metadata_service:
        node_metadata_service.clear_cache()


func _build_node_filter_cache() -> void:
    node_filter.build_cache()


## Register all default commands
func _register_default_commands() -> void:
    # Pass necessary references to the command registrar
    var refs = {
        "controller": self
    }
    DefaultCommandsScript.register_all(registry, refs)


func _input(_event: InputEvent) -> void:
    # NOTE: Keybind handling (MMB, XButton1, XButton2) is now centralized in KeybindsManager
    # This function is kept for any future input handling that shouldn't be rebindable
    pass


## Toggle the palette
func toggle() -> void:
    if not _initialized or not overlay:
        return
    if not _palette_enabled:
        return

    # Ensure metadata service is initialized (recovery)
    if not node_metadata_service:
        _init_node_metadata_service()
        if node_metadata_service:
            overlay.node_metadata_service = node_metadata_service

    overlay.toggle_palette()


## Open the palette
func open() -> void:
    if not _initialized or not overlay:
        return
    if not _palette_enabled:
        return

    # Ensure metadata service is initialized (recovery for hot-reloads)
    if not node_metadata_service:
        _init_node_metadata_service()
        if node_metadata_service:
            # Update overlay with the new service
            overlay.node_metadata_service = node_metadata_service

    overlay.show_palette()


## Close the palette
func close() -> void:
    if not _initialized or not overlay:
        return
    overlay.hide_palette()


## Check if palette is currently open
func is_open() -> bool:
    return overlay and overlay.is_open()


## Get the command registry for external registration
func get_registry() -> RefCounted:
    return registry


## Get the context provider
func get_context() -> RefCounted:
    return context


## Set palette enabled state (middle mouse button toggle)
func set_palette_enabled(enabled: bool) -> void:
    _palette_enabled = enabled
    if mod_config:
        mod_config.set_value("command_palette_enabled", enabled)
    if not enabled and overlay and overlay.is_open():
        overlay.hide_palette()

## Set tab autocomplete enabled state
func set_tab_autocomplete_enabled(enabled: bool) -> void:
    if palette_config:
        palette_config.set_value("tab_autocomplete", enabled)


## Toggle favorite for currently selected command
func toggle_favorite_selected() -> void:
    if overlay and overlay.is_open() and overlay.has_method("_toggle_favorite_selected"):
        overlay._toggle_favorite_selected()


func _on_palette_closed() -> void:
    palette_closed.emit()


func _on_palette_opened() -> void:
    palette_opened.emit()


func _on_command_executed(command_id: String) -> void:
    command_executed.emit(command_id)


## Get the node compatibility filter for port-based filtering
func get_node_filter():
    return node_filter


static func _has_global_class(class_name_str: String) -> bool:
    for entry in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false

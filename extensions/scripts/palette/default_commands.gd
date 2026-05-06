class_name TajsCommandPaletteDefaultCommands
extends RefCounted

const LOG_NAME = "TajsCommandPalette:DefaultCommands"
const CoreServices = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/common/core_services.gd")


## Register all default commands
static func register_all(registry, refs: Dictionary) -> void:
    var controller = refs.get("controller")
    var category_infos: Array[Dictionary] = _get_runtime_categories()

    # ==========================================
    # ROOT CATEGORIES
    # ==========================================

    registry.register({
        "id": "cat_nodes",
        "title": "Nodes",
        "category_path": [],
        "keywords": ["nodes", "windows", "network", "connections"],
        "hint": "Node and connection management",
        "icon_path": "res://textures/icons/connections.png",
        "is_category": true,
        "badge": "SAFE"
    })

    registry.register({
        "id": "cat_tools",
        "title": "Tools",
        "category_path": [],
        "keywords": ["tools", "utilities", "calculator", "math"],
        "hint": "Utility tools and helpers",
        "icon_path": "res://textures/icons/cog.png",
        "is_category": true,
        "badge": "SAFE"
    })

    # Calculator
    registry.register({
        "id": "cmd_calculator",
        "title": "Calculator",
        "display_name": "calculator",
        "aliases": ["calc"],
        "description": "Quick inline math calculator for expressions.",
        "usage": "calc <expression>",
        "examples": ["calc 2+2", "calc sqrt(144)", "= pi * 2^3"],
        "category": "General",
        "tags": ["math", "compute", "calculator"],
        "category_path": ["Tools"],
        "keywords": ["calculator", "calc", "math", "compute", "calculate"],
        "hint": "Open inline calculator (= 2+2)",
        "icon_path": "res://mods-unpacked/TajemnikTV-Core/textures/icons/Accounting-Calculator-1.png",
        "badge": "SAFE",
        "keep_open": true,
        "run": func(_ctx):
            if controller and controller.overlay:
                controller.overlay.search_input.text = "= "
                controller.overlay.search_input.caret_column = 2
                controller.overlay._perform_search()
    })

    # Node Definition / Info
    registry.register({
        "id": "cmd_node_def",
        "title": "Node Definition",
        "display_name": "def",
        "aliases": ["nodeinfo"],
        "description": "Browse node details or open a node's definition panel.",
        "usage": "def <node>",
        "examples": ["def cpu", "def gpu", "def research"],
        "category": "Navigation",
        "tags": ["node", "definition", "info", "help"],
        "category_path": [],
        "keywords": ["def", "nodeinfo", "info", "help", "?", "wiki", "details"],
        "hint": "Show node details (or use 'def <name>')",
        "icon_path": "res://textures/icons/info.png",
        "badge": "SAFE",
        "keep_open": true,
        "run": func(ctx):
            if controller and controller.overlay:
                # Context awareness: if 1 node selected, show its info
                if ctx.selected_node_count == 1:
                    var node = ctx.selected_nodes[0]
                    var id = ""
                    if "id" in node: id = node.id
                    elif "window_id" in node: id = node.window_id
                    elif node.has_method("get_window_id"): id = node.get_window_id()

                    if id != "":
                        controller.overlay.show_node_definition(id)
                        return

                # Default: show node browser with all nodes
                controller.overlay.enter_node_browser()
    })

    # ==========================================
    # NODES - MAIN COMMANDS
    # ==========================================

    registry.register({
        "id": "cmd_select_all_nodes",
        "title": "Select All Nodes",
        "category_path": ["Nodes"],
        "keywords": ["select", "all", "nodes", "everything"],
        "hint": "Select all nodes on the desktop",
        "icon_path": "res://textures/icons/select_all.png",
        "badge": "SAFE",
        "run": func(_ctx):
            if Globals and Globals.desktop:
                var windows_container = Globals.desktop.get_node_or_null("Windows")
                if windows_container:
                    var typed_windows: Array[WindowContainer] = []
                    for child in windows_container.get_children():
                        if child is WindowContainer:
                            typed_windows.append(child)
                    var typed_connectors: Array[Control] = []
                    Globals.set_selection(typed_windows, typed_connectors)
                    CoreServices.notify("check", "Selected %d nodes" % typed_windows.size())
    })

    registry.register({
        "id": "cmd_deselect_all",
        "title": "Deselect All",
        "category_path": ["Nodes"],
        "keywords": ["deselect", "clear", "selection", "none"],
        "hint": "Clear the current selection",
        "badge": "SAFE",
        "run": func(_ctx):
            if Globals:
                var empty_windows: Array[WindowContainer] = []
                var empty_connectors: Array[Control] = []
                Globals.set_selection(empty_windows, empty_connectors)
                CoreServices.notify("check", "Selection cleared")
    })

    registry.register({
        "id": "cmd_center_view",
        "title": "Center View on Selection",
        "category_path": ["Nodes"],
        "keywords": ["center", "focus", "zoom", "view", "camera"],
        "hint": "Center the camera on selected nodes",
        "icon_path": "res://textures/icons/crosshair.png",
        "badge": "SAFE",
        "run": func(_ctx):
            if Globals and Globals.selections.size() > 0:
                var center = Vector2.ZERO
                for window in Globals.selections:
                    center += window.position + window.size / 2
                center /= Globals.selections.size()
                Signals.center_camera.emit(center)
                CoreServices.notify("check", "Centered on %d nodes" % Globals.selections.size())
            else:
                CoreServices.notify("exclamation", "No nodes selected")
    })

    # ==========================================
    # NODES - CATEGORY SUBCATEGORIES
    # ==========================================

    for category_info: Dictionary in category_infos:
        _register_node_category(
            registry,
            str(category_info.get("id", "")),
            str(category_info.get("title", "")),
            str(category_info.get("icon", "cog"))
        )

    # ==========================================
    # NODES - UPGRADE & WIRE COMMANDS
    # ==========================================

    registry.register({
        "id": "cmd_upgrade_selected",
        "title": "Upgrade Selected",
        "category_path": ["Nodes"],
        "keywords": ["upgrade", "selected", "level", "up"],
        "hint": "Upgrade all selected nodes (if affordable)",
        "icon_path": "res://textures/icons/up_arrow.png",
        "badge": "SAFE",
        "run": func(_ctx):
            _upgrade_nodes(Globals.selections if Globals else [])
    })

    registry.register({
        "id": "cmd_clear_wires_selection",
        "title": "Clear All Wires in Selection",
        "category_path": ["Nodes"],
        "keywords": ["clear", "wires", "connections", "disconnect", "selection", "delete"],
        "hint": "Disconnect all wires from selected nodes",
        "icon_path": "res://textures/icons/connections.png",
        "badge": "SAFE",
        "can_run": func(_ctx): return Globals and Globals.selections.size() > 0,
        "run": func(_ctx):
            var result = _clear_wires_for_windows(Globals.selections if Globals else [])
            if result.cleared > 0:
                CoreServices.play_sound("close")
                CoreServices.notify("check", "Cleared %d connections from %d nodes" % [result.cleared, result.nodes])
            else:
                CoreServices.notify("exclamation", "No connections to clear")
    })

    registry.register({
        "id": "cmd_upgrade_all",
        "title": "Upgrade All",
        "category_path": ["Nodes"],
        "keywords": ["upgrade", "all", "level", "up", "everything"],
        "hint": "Upgrade all nodes on desktop (if affordable)",
        "icon_path": "res://textures/icons/up_arrow.png",
        "badge": "SAFE",
        "run": func(_ctx):
            if Globals and Globals.desktop:
                var windows_container = Globals.desktop.get_node_or_null("Windows")
                if windows_container:
                    var all_windows: Array = []
                    for child in windows_container.get_children():
                        if child is WindowContainer:
                            all_windows.append(child)
                    _upgrade_nodes(all_windows)
    })

    _log_info("Registered %d default commands" % registry.get_count())
    _log_category_diagnostics(category_infos)


## Helper to register a node category with select and upgrade commands
static func _register_node_category(registry, cat_id: String, cat_title: String, icon: String) -> void:
    registry.register({
        "id": "cat_nodes_" + cat_id,
        "title": cat_title,
        "category_path": ["Nodes"],
        "keywords": [cat_id, cat_title.to_lower()],
        "hint": cat_title + " nodes",
        "icon_path": "res://textures/icons/" + icon + ".png",
        "is_category": true,
        "badge": "SAFE"
    })

    registry.register({
        "id": "cmd_select_" + cat_id,
        "title": "Select All " + cat_title,
        "category_path": ["Nodes", cat_title],
        "keywords": ["select", "all", cat_id, cat_title.to_lower()],
        "hint": "Select all " + cat_title + " nodes",
        "badge": "SAFE",
        "run": func(_ctx):
            if Globals and Globals.desktop:
                var windows_container = Globals.desktop.get_node_or_null("Windows")
                if windows_container:
                    var typed_windows: Array[WindowContainer] = []
                    for child in windows_container.get_children():
                        if child is WindowContainer:
                            var window_key = ""
                            if "window" in child:
                                window_key = child.window
                            if window_key and window_key in Data.windows:
                                if Data.windows[window_key].category == cat_id:
                                    typed_windows.append(child)
                    var typed_connectors: Array[Control] = []
                    Globals.set_selection(typed_windows, typed_connectors)
                    CoreServices.notify("check", "Selected %d %s nodes" % [typed_windows.size(), cat_title])
    })

    registry.register({
        "id": "cmd_upgrade_" + cat_id,
        "title": "Upgrade " + cat_title,
        "category_path": ["Nodes", cat_title],
        "keywords": ["upgrade", cat_id, cat_title.to_lower(), "level", "up"],
        "hint": "Upgrade all " + cat_title + " nodes (if affordable)",
        "icon_path": "res://textures/icons/up_arrow.png",
        "badge": "SAFE",
        "run": func(_ctx):
            if Globals and Globals.desktop:
                var windows_container = Globals.desktop.get_node_or_null("Windows")
                if windows_container:
                    var category_windows: Array = []
                    for child in windows_container.get_children():
                        if child is WindowContainer:
                            var window_key = ""
                            if "window" in child:
                                window_key = child.window
                            if window_key and window_key in Data.windows:
                                if Data.windows[window_key].category == cat_id:
                                    category_windows.append(child)
                    _upgrade_nodes(category_windows)
    })


## Helper to upgrade a list of nodes with cost checking
static func _upgrade_nodes(windows: Array) -> void:
    var upgraded_count = 0
    var skipped_count = 0

    for window in windows:
        if window == null:
            continue

        if not window.has_method("upgrade"):
            continue

        if window.has_method("can_upgrade"):
            if not window.can_upgrade():
                skipped_count += 1
                continue
            if window.has_method("_on_upgrade_button_pressed"):
                window._on_upgrade_button_pressed()
                upgraded_count += 1
                continue

        var cost = window.get("cost")
        if cost != null and cost > 0:
            if cost > Globals.currencies.get("money", 0):
                skipped_count += 1
                continue
            Globals.currencies["money"] -= cost

        var arg_count = _get_method_arg_count(window, "upgrade")
        if arg_count == 0:
            window.upgrade()
        else:
            window.upgrade(1)
        upgraded_count += 1

    if upgraded_count > 0:
        CoreServices.play_sound("upgrade")
        var msg = "Upgraded " + str(upgraded_count) + " nodes"
        if skipped_count > 0:
            msg += " (" + str(skipped_count) + " skipped)"
        CoreServices.notify("check", msg)
    else:
        CoreServices.play_sound("error")
        if skipped_count > 0:
            CoreServices.notify("exclamation", "Can't afford any upgrades (" + str(skipped_count) + " nodes)")
        else:
            CoreServices.notify("exclamation", "No upgradeable nodes")


## Helper to get method argument count
static func _get_method_arg_count(obj: Object, method_name: String) -> int:
    var script = obj.get_script()
    if script:
        for method in script.get_script_method_list():
            if method.name == method_name:
                return method.args.size()
    return 1


## Helper to clear all wires from a list of windows
static func _clear_wires_for_windows(windows: Array) -> Dictionary:
    var cleared := 0
    var nodes_with_wires := 0

    for window in windows:
        if not is_instance_valid(window):
            continue
        var containers := _find_resource_containers_in_window(window)
        var had_wires := false

        for rc: ResourceContainer in containers:
            if not is_instance_valid(rc):
                continue
            var outputs: Array[String] = rc.outputs_id.duplicate()
            for output_id in outputs:
                Signals.delete_connection.emit(rc.id, output_id)
                cleared += 1
                had_wires = true
            if not rc.input_id.is_empty():
                Signals.delete_connection.emit(rc.input_id, rc.id)
                cleared += 1
                had_wires = true

        if had_wires:
            nodes_with_wires += 1

    return {"cleared": cleared, "nodes": nodes_with_wires}


## Find all ResourceContainers in a window
static func _find_resource_containers_in_window(node: Node) -> Array[ResourceContainer]:
    var containers: Array[ResourceContainer] = []
    _collect_resource_containers(node, containers)
    return containers


## Recursively collect ResourceContainers
static func _collect_resource_containers(node: Node, containers: Array[ResourceContainer]) -> void:
    if node is ResourceContainer:
        containers.append(node as ResourceContainer)
    for child in node.get_children():
        _collect_resource_containers(child, containers)

static func _get_runtime_categories() -> Array[Dictionary]:
    var legacy_order: Array[String] = ["network", "cpu", "gpu", "research", "factory", "hacking", "coding", "utility", "ai", "power"]
    var icon_by_category := {
        "network": "connections",
        "cpu": "bits",
        "gpu": "contrast",
        "research": "atom",
        "ai": "brain",
        "factory": "box",
        "power": "lightning",
        "hacking": "bug",
        "coding": "code",
        "utility": "cog"
    }
    var title_by_category := {
        "network": "Network",
        "cpu": "CPU",
        "gpu": "GPU",
        "research": "Research",
        "ai": "AI",
        "factory": "Factory",
        "power": "Power",
        "hacking": "Hacking",
        "coding": "Coding",
        "utility": "Utility"
    }
    var seen: Dictionary = {}
    var discovered_ids: Array[String] = []
    if Data != null and Data.windows != null:
        for window_id: Variant in Data.windows:
            var window_data: Dictionary = Data.windows.get(window_id, {})
            var category_id: String = str(window_data.get("category", "")).strip_edges()
            if category_id.is_empty() or seen.has(category_id):
                continue
            seen[category_id] = true
            discovered_ids.append(category_id)
    var ordered_ids: Array[String] = []
    for category_id: String in legacy_order:
        if seen.has(category_id):
            ordered_ids.append(category_id)
    var unknown_ids: Array[String] = []
    for category_id: String in discovered_ids:
        if not legacy_order.has(category_id):
            unknown_ids.append(category_id)
    unknown_ids.sort()
    ordered_ids.append_array(unknown_ids)
    var categories: Array[Dictionary] = []
    for category_id: String in ordered_ids:
        categories.append({
            "id": category_id,
            "title": title_by_category.get(category_id, _humanize_category_id(category_id)),
            "icon": icon_by_category.get(category_id, "cog")
        })
    return categories

static func _log_category_diagnostics(category_infos: Array[Dictionary]) -> void:
    if not _is_debug_enabled():
        return
    var category_ids: Array[String] = []
    for info: Dictionary in category_infos:
        category_ids.append(str(info.get("id", "")))
    var generated_category_commands: int = category_infos.size() * 3
    var legacy_ok: bool = (
        category_ids.has("network") and category_ids.has("cpu") and category_ids.has("gpu") and
        category_ids.has("research") and category_ids.has("factory") and category_ids.has("hacking") and
        category_ids.has("coding") and category_ids.has("utility")
    )
    _log_info("Compatibility diagnostics: discovered_categories=%s generated_category_commands=%d ai_generated=%s power_generated=%s" % [
        category_ids,
        generated_category_commands,
        category_ids.has("ai"),
        category_ids.has("power")
    ])
    _log_info("Compatibility diagnostics: legacy_categories_present=%s" % legacy_ok)

static func _is_debug_enabled() -> bool:
    if not Engine.has_meta("TajsCore"):
        return false
    var core = Engine.get_meta("TajsCore")
    if core == null:
        return false
    var core_settings = core.get("settings")
    if core_settings == null:
        return false
    if not core_settings.has_method("get_bool"):
        return false
    return core_settings.get_bool("core.debug", core_settings.get_bool("core.debug_log", false))

static func _log_info(message: String) -> void:
    if Engine.has_meta("TajsCore"):
        var core = Engine.get_meta("TajsCore")
        if core != null and core.has_method("logi"):
            core.logi("TajemnikTV-CommandPalette", message)
            return
    if _has_global_class("ModLoaderLog"):
        ModLoaderLog.info(message, LOG_NAME)
    else:
        print("%s %s" % [LOG_NAME, message])

static func _has_global_class(class_name_str: String) -> bool:
    for entry in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false

static func _humanize_category_id(category_id: String) -> String:
    var lower: String = category_id.to_lower()
    if lower == "ai":
        return "AI"
    if lower == "cpu":
        return "CPU"
    if lower == "gpu":
        return "GPU"
    var parts: PackedStringArray = category_id.split("_", false)
    var title_parts: Array[String] = []
    for part: String in parts:
        if part.is_empty():
            continue
        title_parts.append(part.capitalize())
    return " ".join(title_parts)

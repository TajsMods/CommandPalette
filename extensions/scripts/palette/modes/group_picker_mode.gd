class_name TajsCommandPaletteGroupPickerMode
extends "res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/modes/mode_base.gd"

const PaletteTheme = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/palette_theme.gd")
const CoreServices = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/common/core_services.gd")

## Emitted when a group is selected.
## Payload shape: {group_ref, item_id, handled}
signal group_selected(selection: Dictionary)

# State
var _all_groups: Array[Dictionary] = []
var _items: Array[Dictionary] = []
var _goto_manager = null


func enter() -> void:
    super.enter()


func exit() -> void:
    super.exit()
    _all_groups.clear()
    _items.clear()
    _goto_manager = null


func get_breadcrumb() -> String:
    return "📍 Jump to Group (%d groups)" % _all_groups.size()


func filter(query: String) -> void:
    if query.is_empty():
        _build_items(_all_groups)
    else:
        var filtered: Array = []
        var query_lower := query.to_lower()
        
        for entry: Dictionary in _all_groups:
            var group = entry.get("group_ref", null)
            if not is_instance_valid(group):
                continue
            
            var group_name := _get_group_name(entry)
            if query_lower in group_name.to_lower():
                filtered.append(entry)
        
        _build_items(filtered)
    
    items_updated.emit(_items)


func get_items() -> Array[Dictionary]:
    return _items


func execute_selection(item: Dictionary) -> bool:
    var group = item.get("_group_ref", null)
    
    if not is_instance_valid(group):
        CoreServices.notify("exclamation", "Group no longer exists")
        request_close.emit()
        return true
    
    var item_id := str(item.get("_board_item_id", "group:%s" % str(group.name)))
    var handled := false
    var core = CoreServices._get_core()
    if core != null and core.has_method("board_focus_item"):
        handled = bool(core.board_focus_item(item_id, {"fit": true, "padding": 0.15}))

    group_selected.emit({
        "group_ref": group,
        "item_id": item_id,
        "handled": handled
    })
    
    CoreServices.play_sound("click")
    request_close.emit()
    return true


func handle_back() -> bool:
    # Group picker exits immediately on back
    return false


## Setup the picker with groups
func setup(groups: Array, goto_manager) -> void:
    _goto_manager = goto_manager
    _all_groups = _normalize_groups(groups)
    _build_items(_all_groups)


func _build_items(groups: Array[Dictionary]) -> void:
    _items.clear()
    
    for entry: Dictionary in groups:
        var group = entry.get("group_ref", null)
        if not is_instance_valid(group):
            continue
        
        var group_name := str(entry.get("title", "")).strip_edges()
        if group_name == "":
            group_name = _get_group_name(entry)
        var icon_path := str(entry.get("icon_path", "")).strip_edges()
        if icon_path == "":
            icon_path = _get_group_icon(entry)
        var board_item_id := str(entry.get("item_id", "group:%s" % str(group.name)))
        
        _items.append({
            "id": str(group.get_instance_id()),
            "title": group_name,
            "hint": "",
            "category_path": [],
            "icon_path": icon_path,
            "is_category": false,
            "badge": "SAFE",
            "_group_ref": group,
            "_board_item_id": board_item_id
        })


func _get_group_name(entry: Dictionary) -> String:
    var group = entry.get("group_ref", null)
    if _goto_manager and _goto_manager.has_method("get_group_name"):
        return _goto_manager.get_group_name(group)
    elif group.has_method("get_window_name"):
        return group.get_window_name()
    elif group.get("custom_name") and not group.custom_name.is_empty():
        return group.custom_name
    return "Group"


func _get_group_icon(entry: Dictionary) -> String:
    var group = entry.get("group_ref", null)
    if _goto_manager and _goto_manager.has_method("get_group_icon_path"):
        return _goto_manager.get_group_icon_path(group)
    return "res://textures/icons/window.png"


func _normalize_groups(groups: Array) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for raw: Variant in groups:
        if raw is Dictionary:
            var entry: Dictionary = raw
            var group_ref = entry.get("group_ref", null)
            if not is_instance_valid(group_ref):
                continue
            out.append({
                "group_ref": group_ref,
                "item_id": str(entry.get("item_id", "group:%s" % str(group_ref.name))),
                "title": str(entry.get("title", "")).strip_edges(),
                "icon_path": str(entry.get("icon_path", "")).strip_edges()
            })
            continue
        if is_instance_valid(raw):
            out.append({
                "group_ref": raw,
                "item_id": "group:%s" % str(raw.name),
                "title": "",
                "icon_path": ""
            })
    return out

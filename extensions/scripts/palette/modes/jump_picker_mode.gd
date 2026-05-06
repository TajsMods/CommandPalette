class_name TajsCommandPaletteJumpPickerMode
extends "res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/modes/mode_base.gd"

const CoreServices = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/common/core_services.gd")

## Payload shape: {item_id, type, target_ref, title, handled}
signal jump_selected(selection: Dictionary)

var _all_items: Array[Dictionary] = []
var _items: Array[Dictionary] = []
var _title: String = "Find Anything"

func enter() -> void:
    super.enter()

func exit() -> void:
    super.exit()
    _all_items.clear()
    _items.clear()
    _title = "Find Anything"

func get_breadcrumb() -> String:
    return "🔎 %s (%d items)" % [_title, _all_items.size()]

func filter(query: String) -> void:
    var query_lower := query.to_lower()
    if query_lower.is_empty():
        _build_items(_all_items)
    else:
        var filtered: Array[Dictionary] = []
        for entry: Dictionary in _all_items:
            var search_blob := str(entry.get("search_blob", ""))
            if query_lower in search_blob:
                filtered.append(entry)
        _build_items(filtered)
    items_updated.emit(_items)

func get_items() -> Array[Dictionary]:
    return _items

func execute_selection(item: Dictionary) -> bool:
    var item_id := str(item.get("_item_id", ""))
    var target_ref = item.get("_target_ref", null)
    var item_type := str(item.get("_item_type", ""))

    var handled := false
    var core = CoreServices._get_core()
    if core != null and core.has_method("board_focus_item") and item_id != "":
        handled = bool(core.board_focus_item(item_id, {"fit": item_type == "Group"}))

    jump_selected.emit({
        "item_id": item_id,
        "type": item_type,
        "target_ref": target_ref,
        "title": str(item.get("title", "")),
        "handled": handled
    })

    CoreServices.play_sound("click")
    request_close.emit()
    return true

func handle_back() -> bool:
    return false

func setup(entries: Array, title: String = "Find Anything") -> void:
    _title = title
    _all_items = _normalize_entries(entries)
    _build_items(_all_items)

func _build_items(entries: Array[Dictionary]) -> void:
    _items.clear()
    for entry: Dictionary in entries:
        _items.append({
            "id": str(entry.get("item_id", "")),
            "title": str(entry.get("title", "Unknown")),
            "hint": str(entry.get("hint", "")),
            "category_path": [],
            "icon_path": str(entry.get("icon_path", "")),
            "is_category": false,
            "badge": str(entry.get("badge", "SAFE")),
            "_item_id": str(entry.get("item_id", "")),
            "_item_type": str(entry.get("type", "")),
            "_target_ref": entry.get("target_ref", null)
        })

func _normalize_entries(entries: Array) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for raw: Variant in entries:
        if not (raw is Dictionary):
            continue
        var item_id := str(raw.get("item_id", raw.get("id", "")))
        if item_id == "":
            continue
        var title := str(raw.get("title", "Unknown")).strip_edges()
        var type_name := str(raw.get("type", "Item"))
        var hint := str(raw.get("hint", "")).strip_edges()
        var icon_path := str(raw.get("icon_path", "")).strip_edges()
        var badge := str(raw.get("badge", "SAFE")).strip_edges()
        var target_ref = raw.get("target_ref", raw.get("node_ref", null))
        var search_blob := "%s %s %s" % [title, type_name, hint]
        out.append({
            "item_id": item_id,
            "title": title,
            "type": type_name,
            "hint": hint,
            "icon_path": icon_path,
            "badge": badge,
            "target_ref": target_ref,
            "search_blob": search_blob.to_lower()
        })
    return out

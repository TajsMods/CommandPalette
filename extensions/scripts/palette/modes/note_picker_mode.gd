class_name TajsCommandPaletteNotePickerMode
extends "res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/modes/mode_base.gd"

const PaletteTheme = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/palette_theme.gd")
const CoreServices = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/common/core_services.gd")

## Emitted when a note is selected.
## Payload shape: {note_ref, item_id, handled}
signal note_selected(selection: Dictionary)

# State
var _all_notes: Array[Dictionary] = []
var _items: Array[Dictionary] = []
var _sticky_manager = null


func enter() -> void:
    super.enter()


func exit() -> void:
    super.exit()
    _all_notes.clear()
    _items.clear()
    _sticky_manager = null


func get_breadcrumb() -> String:
    return "📍 Jump to Note (%d notes)" % _all_notes.size()


func filter(query: String) -> void:
    if query.is_empty():
        _build_items(_all_notes)
    else:
        var filtered: Array = []
        var query_lower := query.to_lower()
        
        for entry: Dictionary in _all_notes:
            var note = entry.get("note_ref", null)
            if not is_instance_valid(note):
                continue
            
            var title: String = str(entry.get("title", note.title_text if "title_text" in note else ""))
            var body: String = str(entry.get("body_text", note.body_text if "body_text" in note else ""))
            
            if query_lower in title.to_lower() or query_lower in body.to_lower():
                filtered.append(entry)
        
        _build_items(filtered)
    
    items_updated.emit(_items)


func get_items() -> Array[Dictionary]:
    return _items


func execute_selection(item: Dictionary) -> bool:
    var note = item.get("_note_ref", null)
    
    if not is_instance_valid(note):
        CoreServices.notify("exclamation", "Note no longer exists")
        request_close.emit()
        return true
    
    var item_id := str(item.get("_board_item_id", "note:%s" % str(note.note_id if "note_id" in note else note.name)))
    var handled := false
    var core = CoreServices._get_core()
    if core != null and core.has_method("board_focus_item"):
        handled = bool(core.board_focus_item(item_id, {"fit": false}))

    note_selected.emit({
        "note_ref": note,
        "item_id": item_id,
        "handled": handled
    })
    
    CoreServices.play_sound("click")
    request_close.emit()
    return true


func handle_back() -> bool:
    # Note picker exits immediately on back
    return false


## Setup the picker with notes
func setup(notes: Array, sticky_manager) -> void:
    _sticky_manager = sticky_manager
    _all_notes = _normalize_notes(notes)
    _build_items(_all_notes)


func _build_items(notes: Array[Dictionary]) -> void:
    _items.clear()
    
    for entry: Dictionary in notes:
        var note = entry.get("note_ref", null)
        if not is_instance_valid(note):
            continue
        
        var title := str(entry.get("title", note.title_text if "title_text" in note else "Note"))
        var body := str(entry.get("body_text", note.body_text if "body_text" in note else ""))
        var icon_path := str(entry.get("icon_path", "res://textures/icons/star.png"))
        var board_item_id := str(entry.get("item_id", "note:%s" % str(note.note_id if "note_id" in note else note.name)))
        
        # Truncate body for hint
        var hint = body.replace("\n", " ").substr(0, 50)
        if body.length() > 50:
            hint += "..."
        
        _items.append({
            "id": str(note.get_instance_id()),
            "title": title,
            "hint": hint,
            "category_path": [],
            "icon_path": icon_path,
            "is_category": false,
            "badge": "SAFE",
            "_note_ref": note,
            "_board_item_id": board_item_id
        })


func _normalize_notes(notes: Array) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for raw: Variant in notes:
        if raw is Dictionary:
            var entry: Dictionary = raw
            var note_ref = entry.get("note_ref", null)
            if not is_instance_valid(note_ref):
                continue
            out.append({
                "note_ref": note_ref,
                "item_id": str(entry.get("item_id", "note:%s" % str(note_ref.note_id if "note_id" in note_ref else note_ref.name))),
                "title": str(entry.get("title", "")).strip_edges(),
                "body_text": str(entry.get("body_text", "")),
                "icon_path": str(entry.get("icon_path", "res://textures/icons/star.png"))
            })
            continue
        if is_instance_valid(raw):
            out.append({
                "note_ref": raw,
                "item_id": "note:%s" % str(raw.note_id if "note_id" in raw else raw.name),
                "title": "",
                "body_text": "",
                "icon_path": "res://textures/icons/star.png"
            })
    return out

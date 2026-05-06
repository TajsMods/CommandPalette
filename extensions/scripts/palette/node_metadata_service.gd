class_name TajsCommandPaletteNodeMetadataService
extends RefCounted

const LOG_NAME = "TajsCommandPalette:NodeMetadataService"
const FuzzySearch = preload("res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/fuzzy_search.gd")

# Cache for node metadata
var _node_cache: Array[Dictionary] = []
var _node_details_cache: Dictionary = {}
var _cache_built: bool = false
var _fuzzy_search: RefCounted
var _zero_port_nodes: Array[String] = []
var _scene_resolver: Variant

func _init() -> void:
    _fuzzy_search = FuzzySearch.new()
    if Engine.has_meta("TajsCore"):
        var core: Variant = Engine.get_meta("TajsCore")
        if core != null:
            _scene_resolver = core.get("scene_path_resolver")

## Get all nodes available in the game
## Returns an array of node summaries {id, name, category, icon, score}
func get_all_nodes() -> Array[Dictionary]:
    if not _cache_built:
        _build_cache()
    return _node_cache

## Clear the details cache to force refresh (e.g. when wire colors change)
func clear_cache() -> void:
    _node_details_cache.clear()

## Find nodes matching a query
## Uses fuzzy search to rank results
func find_nodes(query: String) -> Array[Dictionary]:
    if not _cache_built:
        _build_cache()
    
    if query.is_empty():
        return _node_cache
    
    var results: Array[Dictionary] = []
    for node in _node_cache:
        var score = _fuzzy_search.search(query, node.name)
        # Also search description and category for better recall
        var desc_score = _fuzzy_search.search(query, node.get("description", "")) * 0.5
        var cat_score = _fuzzy_search.search(query, node.get("category", "")) * 0.7
        
        # Take the best score
        var final_score = max(score, max(desc_score, cat_score))
        
        if final_score > 0.1: # Threshold to filter noise
            var result = node.duplicate()
            result.score = final_score
            results.append(result)
    
    # Sort by score descending
    results.sort_custom(func(a, b): return a.score > b.score)
    return results

## Get detailed information for a specific node
## Includes inputs/outputs, full description, etc.
func get_node_details(node_id: String) -> Dictionary:
    _log_debug("get_node_details called for '%s'" % node_id)
    
    # Return cached details if available
    if _node_details_cache.has(node_id):
        _log_debug("returning cached details for '%s'" % node_id)
        return _node_details_cache[node_id]
    
    # Fetch from Data.windows
    if not Data.windows.has(node_id):
        _log_debug("'%s' not found in Data.windows" % node_id)
        return {}
    
    var window_data = Data.windows[node_id]
    _log_debug("Extracting details for '%s'" % node_id)
    var details = _extract_node_details(node_id, window_data)
    if details.get("inputs", []).is_empty() and details.get("outputs", []).is_empty():
        if not _zero_port_nodes.has(node_id):
            _zero_port_nodes.append(node_id)
    
    # Cache it
    _node_details_cache[node_id] = details
    return details

## Build the initial cache of node summaries
func _build_cache() -> void:
    _node_cache.clear()
    _zero_port_nodes.clear()
    
    if not Data or not "windows" in Data:
        _log_error("Data.windows not found")
        return
    
    for id in Data.windows:
        var data = Data.windows[id]
        
        # Skip hidden or invalid nodes if possible (optional check)
        # For now, include everything that has a name
        if not data.has("name"):
            continue
            
        var node_summary = {
            "id": id,
            "name": data.get("name", id),
            "category": data.get("category", "Unknown"),
            "sub_category": data.get("sub_category", ""),
            "icon": data.get("icon", "cog"),
            "description": data.get("description", "")
        }
        _node_cache.append(node_summary)
    
    _cache_built = true
    _log_info("Built node metadata cache for %d nodes" % _node_cache.size())
    _log_debug("Node metadata diagnostics: zero_port_nodes=%d sample=%s" % [
        _zero_port_nodes.size(),
        _zero_port_nodes.slice(0, min(10, _zero_port_nodes.size()))
    ])

## Extract detailed info including ports by instantiating the scene
## This is expensive, so it should be cached
func _extract_node_details(node_id: String, data: Dictionary) -> Dictionary:
    var details = {
        "id": node_id,
        "name": data.get("name", node_id),
        "category": data.get("category", "Unknown"),
        "sub_category": data.get("sub_category", ""),
        "icon": data.get("icon", "cog"),
        "description": data.get("description", ""),
        "inputs": [],
        "outputs": [],
        "modifiers_added": [],
        "scene_path": ""
    }
    
    # Try to get scene-based details (ports)
    if data.has("scene"):
        var scene_info: Dictionary = _resolve_window_scene_path(data)
        var scene_path: String = str(scene_info.get("resolved", ""))
        details.scene_path = scene_path
        
        if ResourceLoader.exists(scene_path):
            var scene = load(scene_path)
            if scene:
                var instance = scene.instantiate()
                if instance:
                    _collect_ports(instance, details)
                    instance.queue_free()
            else:
                _log_debug("Scene resolution failed for '%s': scene=%s resolved=%s attempted=%s reason=load_failed" % [
                    node_id,
                    str(scene_info.get("original", "")),
                    scene_path,
                    str(scene_info.get("attempted", []))
                ])
        else:
            _log_debug("Scene resolution failed for '%s': scene=%s resolved=%s attempted=%s reason=missing_resource" % [
                node_id,
                str(scene_info.get("original", "")),
                scene_path,
                str(scene_info.get("attempted", []))
            ])
    
    # Add unlock info if available (heuristic-based for now)
    details.unlock_info = _get_unlock_info(node_id, data)
    details.modifiers_added = _extract_modifiers(node_id, data)
    
    return details

func _resolve_window_scene_path(data: Dictionary) -> Dictionary:
    var scene_value: String = str(data.get("scene", ""))
    if _scene_resolver != null and _scene_resolver.has_method("resolve_window_scene"):
        return _scene_resolver.resolve_window_scene(scene_value)
    if scene_value.is_empty():
        return {"original": scene_value, "resolved": "", "attempted": []}
    var attempted: Array[String] = []
    if scene_value.begins_with("res://"):
        var resolved_abs: String = scene_value if scene_value.ends_with(".tscn") else (scene_value + ".tscn")
        attempted.append(resolved_abs)
        return {"original": scene_value, "resolved": resolved_abs, "attempted": attempted}
    var resolved_rel: String = "res://scenes/windows/" + scene_value + ".tscn"
    attempted.append(resolved_rel)
    attempted.append(scene_value)
    return {"original": scene_value, "resolved": resolved_rel, "attempted": attempted}

## Helper to recursively collect port info
func _collect_ports(node: Node, details: Dictionary) -> void:
    # Use duck typing/property check instead of class_name to avoid potential scope issues
    # We check for a property unique enough to ResourceContainer
    if node.get("default_resource") != null:
        var shape = node.get("override_connector")
        if shape == null: shape = "" # Handle potential null
        
        var color = node.get("override_color")
        if color == null or color == "": color = "white"
        
        var default_res = node.get("default_resource")
        if shape.is_empty() and default_res != "" and Data.resources.has(default_res):
            var res_data = Data.resources[default_res]
            shape = res_data.get("connection", "")
            if color == "white": # Only override if not set
                color = res_data.get("color", "white")
        
        # Also need to cast to something compatible or just access properties dynamically
        # Since we verified default_resource exists, we can access others dynamically
        var rc_default_resource = default_res
        
        if not shape.is_empty():
            var port_info = {
                "shape": shape,
                "color": color,
                "label": node.name, # Usually useful label
                "count": 1, # Can be used for grouping
                "resource_id": rc_default_resource
            }
            
            var is_input: bool = node.has_node("InputConnector") or node.is_in_group("input")
            var is_output: bool = node.has_node("OutputConnector") or node.is_in_group("output")
            if is_input:
                _add_port_to_list(details.inputs, port_info)
            if is_output:
                _add_port_to_list(details.outputs, port_info)
    
    for child in node.get_children():
        _collect_ports(child, details)

## Helper to add port to list or increment count if identical exists
func _add_port_to_list(list: Array, port: Dictionary) -> void:
    # Try to find identical port to group them (e.g. 6x Data Input)
    for existing in list:
        if existing.shape == port.shape and existing.color == port.color and existing.label == port.label:
            existing.count += 1
            return
    list.append(port)

## Try to determine unlock info
func _get_unlock_info(_node_id: String, data: Dictionary) -> Dictionary:
    # Heuristic: Check if it's a base node or research locked
    # This part is speculative as we haven't found explicit unlock data in the mod files
    # But we can allow for manual overrides or future expansion
    var info = {
        "status": "Available"
    }
    
    if data.has("research_id"):
        info.status = "Research Required"
        info.research_id = data.research_id
        # Could look up research name if we can access Research data
        if Data.has("research") and Data.research.has(data.research_id):
            info.research_name = Data.research[data.research_id].get("name", data.research_id)
            
    return info

# Hardcoded mapping of nodes to modifiers applied programmatically.
const NODE_MODIFIERS := {
    "virus_scanner": ["scanned", "infected"],
    "antivirus_pro": ["scanned"],
    "quarantine": ["scanned"],
    "verifier": ["validated", "corrupted"],
    "compressor": ["compressed"],
    "lossless_compressor": ["compressed", "enhanced"],
    "enhancer": ["enhanced"],
    "refiner": ["refined"],
    "analyzer": ["analyzed"],
    "distillator": ["distilled"],
    "decryptor": ["decrypted"],
    "virus_extractor": ["infected"],
    "trojan_injector": ["trojan"],
    "data_lab": ["analyzed"],
    "torrent_browser_scanned": ["scanned"],
    "torrent_browser_verified": ["validated"],
    "torrent_browser_analyzed": ["analyzed"],
    "torrent_browser_encrypted": ["encrypted"],
    "encryptor": ["encrypted"],
    "generator_text": ["ai"],
    "generator_image": ["ai"],
    "generator_sound": ["ai"],
    "generator_video": ["ai"],
    "generator_program": ["ai"],
    "generator_game": ["ai"]
}

const FILE_MODIFIERS := {
    "scanned": {"name": "Scanned", "icon": "antivirus", "description_key": "guide_file_modifiers_scanned"},
    "validated": {"name": "Validated", "icon": "puzzle", "description_key": "guide_file_modifiers_validated"},
    "compressed": {"name": "Compressed", "icon": "minimize", "description_key": "guide_file_modifiers_compressed"},
    "enhanced": {"name": "Enhanced", "icon": "up_arrow", "description_key": "guide_file_modifiers_enhanced"},
    "infected": {"name": "Infected", "icon": "virus", "description_key": "guide_file_modifiers_infected"},
    "refined": {"name": "Refined", "icon": "filter", "description_key": "guide_file_modifiers_refined"},
    "distilled": {"name": "Distilled", "icon": "connections", "description_key": "guide_file_modifiers_distilled"},
    "analyzed": {"name": "Analyzed", "icon": "magnifying_glass", "description_key": "guide_file_modifiers_analyzed"},
    "hacked": {"name": "Hacked", "icon": "hacker", "description_key": "guide_file_modifiers_hacked"},
    "corrupted": {"name": "Corrupted", "icon": "warning", "description_key": "guide_file_modifiers_corrupted"},
    "ai": {"name": "AI", "icon": "brain", "description_key": "guide_file_modifiers_ai"},
    "encrypted": {"name": "Encrypted", "icon": "padlock", "description_key": "guide_file_modifiers_encrypted"},
    "decrypted": {"name": "Decrypted", "icon": "padlock_open", "description_key": "guide_file_modifiers_decrypted"},
    "trojan": {"name": "Trojan", "icon": "trojan", "description_key": "guide_file_modifiers_trojan"}
}

func _extract_modifiers(node_id: String, data: Dictionary) -> Array:
    var modifier_ids: Array = []
    var seen: Dictionary = {}
    var known_keys: Array[String] = [
        "modifier", "modifiers", "adds_modifier", "adds_modifiers",
        "add_modifier", "add_modifiers", "file_modifier", "file_modifiers",
        "output_modifier", "output_modifiers", "input_modifier", "input_modifiers",
        "modifiers_add", "modifier_add"
    ]
    for key: String in known_keys:
        if data.has(key):
            _append_modifier_value(modifier_ids, seen, data[key])
    for key: Variant in data.keys():
        var key_name: String = str(key).to_lower()
        if key_name.find("modifier") == -1:
            continue
        _append_modifier_value(modifier_ids, seen, data[key])
    if modifier_ids.is_empty() and NODE_MODIFIERS.has(node_id):
        for mod: String in NODE_MODIFIERS[node_id]:
            if not seen.has(mod):
                seen[mod] = true
                modifier_ids.append(mod)
    var result: Array = []
    for modifier_id: Variant in modifier_ids:
        result.append(_resolve_modifier_meta(str(modifier_id)))
    return result

func _append_modifier_value(list: Array, seen: Dictionary, value: Variant) -> void:
    if value == null:
        return
    if value is String:
        var id: String = str(value)
        if not id.is_empty() and not seen.has(id):
            seen[id] = true
            list.append(id)
    elif value is Array:
        for entry: Variant in value:
            _append_modifier_value(list, seen, entry)
    elif value is Dictionary:
        if value.has("id"):
            _append_modifier_value(list, seen, value["id"])
        elif value.has("modifier"):
            _append_modifier_value(list, seen, value["modifier"])

func _resolve_modifier_meta(modifier_id: String) -> Dictionary:
    var meta: Dictionary = {
        "id": modifier_id,
        "name": modifier_id.capitalize(),
        "description": ""
    }
    var id_lower: String = modifier_id.to_lower()
    if FILE_MODIFIERS.has(id_lower):
        var fm: Dictionary = FILE_MODIFIERS[id_lower]
        meta.name = fm.get("name", modifier_id.capitalize())
        meta.icon = fm.get("icon", "")
        var desc_key: String = str(fm.get("description_key", ""))
        if not desc_key.is_empty():
            var translated_desc: String = tr(desc_key)
            if translated_desc != desc_key:
                meta.description = translated_desc
            return meta
    if Data.resources.has(modifier_id):
        var res: Dictionary = Data.resources[modifier_id]
        meta.name = tr(res.get("name", modifier_id))
        meta.description = tr(res.get("description", ""))
        if res.has("icon"):
            meta.icon = res.get("icon", "")
        return meta
    if "items" in Data and Data.items.has(modifier_id):
        var item: Dictionary = Data.items[modifier_id]
        meta.name = tr(item.get("name", modifier_id))
        meta.description = tr(item.get("description", ""))
        if item.has("icon"):
            meta.icon = item.get("icon", "")
        return meta
    var guide_key: String = "guide_file_modifiers_" + id_lower
    var translated_guide: String = tr(guide_key)
    if translated_guide != guide_key:
        meta.description = translated_guide
    return meta

func _is_debug_enabled() -> bool:
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

func _log_debug(message: String) -> void:
    if _is_debug_enabled():
        _log_info("DEBUG: %s" % message)

func _log_info(message: String) -> void:
    if Engine.has_meta("TajsCore"):
        var core = Engine.get_meta("TajsCore")
        if core != null and core.has_method("logi"):
            core.logi("TajemnikTV-CommandPalette", message)
            return
    if _has_global_class("ModLoaderLog"):
        ModLoaderLog.info(message, LOG_NAME)
    else:
        print("%s %s" % [LOG_NAME, message])

func _log_error(message: String) -> void:
    if Engine.has_meta("TajsCore"):
        var core = Engine.get_meta("TajsCore")
        if core != null and core.has_method("loge"):
            core.loge("TajemnikTV-CommandPalette", message)
            return
    if _has_global_class("ModLoaderLog"):
        ModLoaderLog.error(message, LOG_NAME)
    else:
        print("%s %s" % [LOG_NAME, message])

static func _has_global_class(class_name_str: String) -> bool:
    for entry in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false

# ==============================================================================
# Command Palette - Core Services Helper
# Author: TajemnikTV
# Description: Routes notifications, sound, and clipboard through Core when available
# ==============================================================================
extends RefCounted

const CORE_META_KEY := "TajsCore"

static func _get_core():
	if Engine.has_meta(CORE_META_KEY):
		var core = Engine.get_meta(CORE_META_KEY)
		if core != null:
			return core
	return null

static func notify(icon: String, message: String) -> void:
	var core = _get_core()
	if core != null and core.has_method("notify"):
		core.notify(icon, message)
		return
	var signals = _get_autoload("Signals")
	if signals != null and signals.has_signal("notify"):
		signals.emit_signal("notify", icon, message)

static func play_sound(sound_id: String) -> void:
	var core = _get_core()
	if core != null and core.has_method("play_sound"):
		core.play_sound(sound_id)
		return
	var sound = _get_autoload("Sound")
	if sound != null and sound.has_method("play"):
		sound.play(sound_id)

static func clipboard_set(text: String) -> void:
	var core = _get_core()
	if core != null and core.has_method("copy_to_clipboard"):
		core.copy_to_clipboard(text)
		return
	DisplayServer.clipboard_set(text)

static func _get_autoload(name: String) -> Object:
	if Engine.has_singleton(name):
		return Engine.get_singleton(name)
	if Engine.get_main_loop() == null:
		return null
	var root = Engine.get_main_loop().root
	if root == null:
		return null
	return root.get_node_or_null(name)

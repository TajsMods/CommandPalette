# ==============================================================================
# Command Palette - Palette Config Wrapper (Compatibility)
# Author: TajemnikTV
# Description: Legacy wrapper that forwards to Core command palette settings
# ==============================================================================
class_name TajsModPaletteConfig
extends "res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/palette_settings.gd"

func setup(mod_config_ref) -> void:
	if mod_config_ref != null:
		_palette = mod_config_ref
	else:
		super.setup(null, null)

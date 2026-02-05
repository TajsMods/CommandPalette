class_name TajsModPaletteConfig
extends "res://mods-unpacked/TajemnikTV-CommandPalette/extensions/scripts/palette/palette_settings.gd"

func setup(mod_config_ref = null, _unused = null) -> void:
    if mod_config_ref != null:
        _palette = mod_config_ref
    else:
        super.setup(null, null)

extends Node
## Single source of truth for zone-linked platform and landing-feedback colors.
## A future zone controller switches the active Resource with set_palette().

signal palette_changed(palette: ZoneFeedbackPalette)

const DEFAULT_PALETTE: ZoneFeedbackPalette = preload("res://resources/palettes/default_neon_zone.tres")

var current_palette: ZoneFeedbackPalette = DEFAULT_PALETTE


func set_palette(palette: ZoneFeedbackPalette) -> void:
	if palette == null:
		push_warning("ZonePaletteManager: palette cannot be null.")
		return
	if current_palette == palette:
		return
	current_palette = palette
	palette_changed.emit(current_palette)


func reset_to_default() -> void:
	set_palette(DEFAULT_PALETTE)

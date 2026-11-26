extends Control
## Original dialogue border slices; two display units per native pixel.
const CURSORS = preload("res://assets/vendor/stardew-island/ui/Cursors.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

func _draw() -> void:
	_piece(Rect2(12, 10, size.x - 24, size.y - 20), Rect2(306, 320, 16, 16))
	_piece(Rect2(24, 0, size.x - 48, 12), Rect2(275, 313, 1, 6))
	_piece(Rect2(24, size.y - 16, size.x - 48, 16), Rect2(275, 328, 1, 8))
	_piece(Rect2(0, 22, 16, size.y - 44), Rect2(264, 325, 8, 1))
	_piece(Rect2(size.x - 14, 20, 14, size.y - 40), Rect2(293, 324, 7, 1))
	_piece(Rect2(0, 0, 28, 26), Rect2(261, 311, 14, 13))
	_piece(Rect2(size.x - 24, 0, 24, 22), Rect2(291, 311, 12, 11))
	_piece(Rect2(0, size.y - 22, 28, 22), Rect2(261, 327, 14, 11))
	_piece(Rect2(size.x - 24, size.y - 24, 24, 24), Rect2(291, 326, 12, 12))

func _piece(destination: Rect2, source: Rect2) -> void:
	draw_texture_rect_region(CURSORS, destination, source)

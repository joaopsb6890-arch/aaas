extends Node3D

const LIFETIME: float = 8.0

func _ready() -> void:
	var t := create_tween()
	t.tween_interval(LIFETIME)
	t.tween_callback(queue_free)

extends Node3D
## Cena de jogo: liga menus, HUD do carro e definições.


func _ready() -> void:
	Global.enter_game()
	var menus := preload("res://ui/game_menus.gd").new()
	menus.name = "GameMenus"
	add_child(menus)
	var overlay := preload("res://ui/game_overlay.gd").new()
	overlay.name = "GameOverlay"
	add_child(overlay)
	GameSettings.apply_graphics()
	GameSettings.apply_to_scene(self)

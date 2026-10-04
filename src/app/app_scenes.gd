class_name AppScenes
extends RefCounted
## Fluxo de navegação do app, num lugar só:
##   Menu principal -> (futuro: gerenciador de campanhas) -> Mesa (VTT)
## Trocar de tela = trocar de cena do Godot; nada de estado de sessão sobrevive à troca.

const MENU := "res://src/app/main_menu.tscn"
const TABLE := "res://src/app/vtt_table.tscn"


static func open(tree: SceneTree, path: String) -> void:
	var err := tree.change_scene_to_file(path)
	if err != OK:
		Log.error("falha ao abrir %s (erro %d)" % [path, err])

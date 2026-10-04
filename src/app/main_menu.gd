extends Control
## Menu principal. Só navegação: não contém lógica de sessão.
## Hoje "Jogar" abre a mesa direto. Quando existir o sistema de campanhas,
## "Jogar" passa a abrir o gerenciador de campanhas (e só ele abre a mesa).

var _play_button: Button


func _ready() -> void:
	# Libera texturas que a mesa anterior (se houve) deixou sem uso.
	AssetRegistry.collect_unused()
	_build()
	# _play_button.grab_focus()   # Enter/Espaço/gamepad funcionam sem mouse


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1b1d23")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var title := Label.new()
	title.text = "P-VTT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Mesa virtual de RPG"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.6)
	column.add_child(subtitle)

	var gap := Control.new()
	gap.custom_minimum_size.y = 24
	column.add_child(gap)

	_play_button = _make_button("Jogar")
	_play_button.pressed.connect(_on_play)
	column.add_child(_play_button)

	# Em Web não existe "sair" (a aba é do usuário), então o botão não é mostrado.
	if not OS.has_feature("web"):
		var quit_button := _make_button("Sair")
		quit_button.pressed.connect(_on_quit)
		column.add_child(quit_button)


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 52)
	return b


func _on_play() -> void:
	AppScenes.open(get_tree(), AppScenes.TABLE)


func _on_quit() -> void:
	get_tree().quit()

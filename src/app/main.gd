extends Node
## Composition root: o único lugar que conhece todas as peças e as liga.
## Modo atual: OFFLINE = servidor + 1 cliente (Mestre) no mesmo processo via LocalLink.
## Multiplayer (Milestone 5) troca apenas o transporte; nada abaixo muda.

const ASSET_GC_INTERVAL := 30.0

var server: VttServer
var session: ClientSession
var camera: CameraController
var grid: GridRenderer
var token_layer: TokenLayer
var selection: SelectionManager
var interaction: TokenInteraction
var router: InputRouter
var ui: UiRoot


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("1b1d23"))

	# --- Servidor autoritativo + cliente, ligados por um transporte local ---
	var link := LocalLink.new()
	server = VttServer.new(_make_demo_campaign(), link.server)
	session = ClientSession.new(link.create_client(), "Mestre")

	# --- Mundo (apresentação) ---
	var world := Node2D.new()
	world.name = "World"
	add_child(world)

	camera = CameraController.new()
	world.add_child(camera)

	grid = GridRenderer.new()
	grid.z_index = -10
	world.add_child(grid)
	grid.setup(camera)

	token_layer = TokenLayer.new()
	world.add_child(token_layer)

	var box := SelectionBoxView.new()
	box.z_index = 100
	world.add_child(box)

	# --- Sistemas ---
	selection = SelectionManager.new()
	token_layer.bind(session, selection)
	interaction = TokenInteraction.new(session, token_layer, selection, box)
	interaction.view_center = func() -> Vector2: return camera.position

	# --- Input -> Command -> Sistema ---
	router = InputRouter.new()
	router.to_world = camera.screen_to_world
	add_child(router)
	router.command_issued.connect(_dispatch)

	# --- UI ---
	ui = UiRoot.new()
	add_child(ui)
	ui.setup(session)
	ui.command_issued.connect(_dispatch)
	ui.stats_provider = func() -> Dictionary:
		return {"tokens": token_layer.token_count(), "assets": AssetRegistry.loaded_count()}

	# --- Reações a eventos da sessão ---
	session.scene_loaded.connect(_on_scene_loaded)
	session.token_removed.connect(selection.remove)

	# --- Coleta periódica de assets sem uso ---
	var gc := Timer.new()
	gc.wait_time = ASSET_GC_INTERVAL
	gc.autostart = true
	gc.timeout.connect(AssetRegistry.collect_unused)
	add_child(gc)


## Roteia comandos para o sistema responsável.
func _dispatch(cmd: Object) -> void:
	if cmd is Cmd.Pan:
		camera.pan_by_screen((cmd as Cmd.Pan).screen_delta)
	elif cmd is Cmd.Zoom:
		camera.zoom_at((cmd as Cmd.Zoom).factor, (cmd as Cmd.Zoom).screen_pos)
	elif cmd is Cmd.ResetView:
		camera.reset_view()
	else:
		interaction.handle(cmd)


func _on_scene_loaded(scene: SceneData) -> void:
	selection.clear()
	grid.set_cell_size(scene.grid_size)
	Log.info(Log.SCENE, "cena carregada no cliente: %s (%d tokens)" % [scene.scene_name, scene.tokens.size()])


func _make_demo_campaign() -> CampaignData:
	var c := CampaignData.new()
	c.id = "demo"
	c.campaign_name = "Campanha de Demonstração"

	var tavern := SceneData.new()
	tavern.id = "tavern"
	tavern.scene_name = "Taverna"
	_demo_token(tavern, "Aria", Vector2(-128, 0), Vector2.ONE)
	_demo_token(tavern, "Borin", Vector2(0, 0), Vector2.ONE)
	_demo_token(tavern, "Goblin", Vector2(192, 64), Vector2.ONE)
	_demo_token(tavern, "Ogro", Vector2(192, -128), Vector2(2, 2))
	c.add_scene(tavern)

	var forest := SceneData.new()
	forest.id = "forest"
	forest.scene_name = "Floresta"
	_demo_token(forest, "Lobo", Vector2(64, 64), Vector2.ONE)
	_demo_token(forest, "Elfo", Vector2(-64, -64), Vector2.ONE)
	c.add_scene(forest)
	return c


func _demo_token(scene: SceneData, token_name: String, pos: Vector2, scl: Vector2) -> void:
	var t := TokenData.new()
	t.id = Ids.new_id("t")
	t.token_name = token_name
	t.position = pos
	t.scale = scl
	scene.add_token(t)

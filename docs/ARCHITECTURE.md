# P-VTT — Arquitetura (Milestone 1 + base de 2 e 3)

Godot 4.3+ · GDScript · servidor autoritativo desde o primeiro dia.

## 1. Estrutura de pastas

```
p-vtt/
├── project.godot
├── docs/ARCHITECTURE.md
├── tests/                      # testes headless (cenas rodáveis)
└── src/
	├── core/                   # ESTADO PERSISTENTE. Sem Node, sem UI, sem rede.
	│   ├── campaign_data.gd    # Campaign -> N cenas + cena ativa
	│   ├── scene_data.gd       # Cena: grid, fundo, tokens, walls/doors (reservado)
	│   ├── token_data.gd       # Token: id, pos, rot, scale, asset, layer, visível, dono, props
	│   ├── roles.gd            # MASTER / PLAYER / SPECTATOR + regras de permissão
	│   └── ids.gd              # geração de ids (sempre no servidor)
	├── net/                    # Networking
	│   ├── proto.gd            # tipos de mensagem, limites, validadores de campo
	│   ├── server_transport.gd # interface abstrata (lado servidor)
	│   ├── client_transport.gd # interface abstrata (lado cliente)
	│   ├── local_link.gd       # transporte em memória (offline e testes)
	│   ├── vtt_server.gd       # LÓGICA AUTORITATIVA: valida, muda estado, replica
	│   └── client_session.gd   # réplica local + API de pedidos
	├── client/                 # APRESENTAÇÃO (estado temporário)
	│   ├── camera/camera_controller.gd
	│   ├── rendering/          # grid_renderer, token_layer, token_view, selection_box_view
	│   ├── input/              # input_router (eventos -> comandos), commands
	│   └── ui/ui_root.gd       # barra superior + overlay de debug (sem lógica de negócio)
	├── systems/
	│   ├── selection/selection_manager.gd
	│   └── token_interaction/token_interaction.gd
	└── app/                    # navegação, composition root + autoloads
		├── main_menu.gd/.tscn  # cena inicial: Jogar / Sair
		├── app_scenes.gd       # fluxo de telas (caminhos + open())
		├── vtt_table.gd/.tscn  # a MESA: composition root de uma sessão de VTT
		├── log.gd              # autoload: logs por categoria
		└── asset_registry.gd   # autoload: cache + contagem de uso de texturas
```

### Fluxo do app

```
Menu principal ──Jogar──► Mesa (VTT)      ◄── hoje
	   ▲                     │
	   └─────── Menu ────────┘

Menu principal ──Jogar──► Campanhas ──abrir campanha X──► Mesa(X)   ◄── Milestone 3
```
Cada tela é uma cena do Godot; `AppScenes` concentra a navegação. A mesa não guarda nada em
autoload: servidor, sessão e câmera nascem e morrem com a cena `vtt_table`, então voltar ao
menu descarta a sessão e libera as texturas (testado). Quando houver campanhas, só muda quem
chama `AppScenes.open` e o que a mesa recebe ao iniciar (a campanha escolhida, em vez da demo).

Regra de dependência (só aponta para baixo):

```
app (mesa)  ->  client, systems  ->  net/client_session  ->  core
							  net/vtt_server      ->  core
```
`core` não importa nada. `vtt_server` não conhece Node, câmera nem UI.

## 2. Como as partes se comunicam

### Escrita (qualquer mudança no mundo)

```
Mouse/toque
   │  InputEvent
   ▼
InputRouter ──Cmd.PointerDown/Move/Up, Pan, Zoom, Delete…──► _dispatch (Main)
																 │
					   ┌─────────────────────────────────────────┤
					   ▼                                         ▼
			   CameraController                          TokenInteraction ◄── SelectionManager
			   (só apresentação)                                 │
																 │ request_move_tokens(...)
																 ▼
														  ClientSession
																 │ REQ_MOVE_TOKENS  (Transport)
																 ▼
															VttServer
											  valida: papel, dono, escopo da cena,
											  tipos, NaN/Inf, limites, tamanho
																 │ muda CampaignData
																 │ EVT_TOKENS_MOVED  (só o delta)
																 ▼
														  ClientSession (réplica)
																 │ signal tokens_moved
																 ▼
													TokenLayer -> TokenView.update_from()
```

- O cliente **nunca** altera a réplica por conta própria. Durante o arrasto só a
  *view* se move (preview, estado temporário). Ao soltar, vai **um** pedido com
  todos os tokens movidos. Se o servidor negar, ele devolve a posição autoritativa
  (`EVT_TOKENS_MOVED` só para quem pediu) + `EVT_REJECTED`, e a view volta.
- Offline e multiplayer usam **o mesmo** `VttServer` e o mesmo `ClientSession`.
  Só muda o transporte (`LocalLink` hoje; ENet/WebSocket no Milestone 5).

### Mensagens atuais (`proto.gd`)

| Cliente → Servidor | Servidor → Cliente |
|---|---|
| `REQ_HELLO` | `EVT_WELCOME` (peer_id, papel) |
| `REQ_MOVE_TOKENS` (lote) | `EVT_SNAPSHOT` (campanha resumida + cena ativa) |
| `REQ_ADD_TOKEN` (Mestre) | `EVT_TOKEN_ADDED` |
| `REQ_REMOVE_TOKEN` (Mestre) | `EVT_TOKENS_MOVED` (só os que mudaram) |
| `REQ_SWITCH_SCENE` (Mestre) | `EVT_TOKEN_REMOVED` |
| | `EVT_REJECTED` (pedido, motivo) |

Mensagens são `Dictionary` simples → servem para qualquer transporte/serialização.

### Estado persistente × temporário

| Persistente (`core/`, servidor é a verdade) | Temporário (`client/`, `systems/`) |
|---|---|
| Campaign, Scene, Token (pos, rot, scale, asset, layer, visibilidade, dono, props), walls/doors/fog (futuro) | Seleção, preview de arrasto, posição/zoom da câmera, hover, UI, caixa de seleção |

`to_dict()/from_dict()` já existem para JSON (Milestone 3: `campaign.json` + `scenes/<id>.json`).
Nada de apresentação entra neles.

## 3. Decisões e por quê

1. **Servidor autoritativo + transporte abstrato.** Multiplayer não vira "patch": o modo
   offline já passa por `Request → validação → estado → replicação`. Trocar para rede = nova
   implementação de `ServerTransport`/`ClientTransport`.
2. **Replicação por delta.** Um token movido = uma entrada em `EVT_TOKENS_MOVED`; nada de
   estado contínuo a 60 Hz. Snapshot completo só no handshake e na troca de cena.
3. **Visibilidade filtrada no servidor.** Tokens ocultos nunca são enviados a jogadores
   (snapshot e deltas), não são só escondidos na UI.
4. **Permissões num lugar só (`Roles`).** O servidor decide; o cliente reaproveita a mesma
   função apenas para UX (não iniciar um arrasto que seria negado).
5. **Input → Command → System.** Sistemas nunca leem `InputEvent`. Toque/gamepad no futuro =
   novo roteador gerando os mesmos comandos. A câmera é injetada como `Callable`.
6. **AssetRegistry.** `acquire(id)/release(id)` com contagem de uso, cache por id, falhas
   memorizadas (não tenta de novo a cada frame), `collect_unused()` periódico e ao trocar de
   cena, texturas limitadas a 2048 px. Tokens sem imagem compartilham **uma** textura de
   placeholder. IDs de asset aceitos: `builtin:`, `res://`, `user://` (sem `..`).
7. **Render sob demanda.** Grid, seleção e tokens só chamam `queue_redraw()` quando algo
   muda. O grid desenha só a área visível, com LOD (limita o número de linhas em qualquer zoom).
   A UI de debug não custa nada quando oculta (F3).
8. **Composição.** Classes pequenas, sem herança profunda; `main.gd` é o único que liga tudo.

## 4. "Isso funciona com 1000 tokens, 100 cenas, vários jogadores e internet?"

| Ponto | Hoje | Limite conhecido / próximo passo |
|---|---|---|
| Rede | deltas por lote; sem envio contínuo | Milestone 6: compressão, coalescência de movimentos, rate limit por peer |
| 100 cenas | só a cena ativa existe em memória no cliente; snapshot só da ativa | Milestone 3: carregar/descarregar cenas do disco sob demanda |
| 1000 tokens | views só mudam quando o token muda | `pick()` e box-select são O(n); trocar por grid espacial se passar de poucas centenas |
| Draw calls | cada token = 1 Sprite2D (batching automático do Godot com a mesma textura) | MultiMesh/atlas se virar gargalo |
| Memória | texturas com contagem de uso e GC | thumbnails + mipmaps no Milestone 2 |
| Segurança | papel, dono, escopo de cena, tipo/NaN/Inf, limites de lote e de nome, ids de asset | autenticação real, limite de tamanho de mensagem no transporte de rede, rate limit |

## 5. Limitações conhecidas desta base

- Só existe o transporte local. Não há ENet/WebSocket ainda (Milestone 5).
- O papel é provisório: peer 1 = Mestre, demais = Jogador (autenticação no Milestone 6).
- Sem persistência em disco ainda (modelo de dados e `to_dict` prontos; Milestone 3).
- Sem fundo de mapa renderizado (`background_asset_id` reservado), sem escala/rotação
  interativas, sem walls/doors/fog.
- Sessões são objetos de vida longa. `VttServer`/`ClientSession` e o transporte se referenciam
  por sinais; quando houver reconexão (Milestone 6), adicionar um `close()` explícito que
  desconecte os sinais. (Ao fechar o programa, o Godot imprime avisos de objetos ainda vivos;
  é esperado por isso e não é vazamento em execução.)
- Apenas mouse/teclado hoje; a separação por comandos deixa o caminho livre para toque.

## 6. Testes

```
godot --headless --path . res://tests/test_net.tscn      # core + servidor + permissões + assets
godot --headless --path . res://tests/test_client.tscn   # cliente dirigido por comandos
godot --headless --path . res://tests/test_menu.tscn     # navegação Menu -> Mesa -> Menu
```
Rodam como cenas (e não com `-s`) para que os autoloads existam.

## 7. Próximos milestones

2. Tokens: assets reais (importar imagem, thumbnail), rotação e escala interativas.
3. Cenas: salvar/carregar JSON por cena, criar/renomear/excluir cenas.
4. Editor: ferramentas, paredes, portas, objetos.
5. Multiplayer: `ENetServerTransport`/`ENetClientTransport` implementando as interfaces atuais.

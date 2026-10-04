# P-VTT

Virtual Tabletop em Godot 4.3+ com arquitetura servidor-autoritativo.
Veja `docs/ARCHITECTURE.md`.

## Rodar
1. Abra a pasta no Godot 4.3 (ou superior) e aperte F5. Abre o menu principal; **Jogar** entra na mesa.
2. Na mesa, o botão **Menu** (barra superior) volta ao menu. Controles: roda do mouse = zoom · botão do meio/direito arrastando = mover a vista ·
   clique = selecionar · Ctrl+clique = multi · Shift+arrastar = seleção por área ·
   arrastar token = mover (snap de meia célula; Alt desliga) · Delete = excluir ·
   Home = resetar vista · F3 = overlay de debug.
3. Barra superior (Mestre): trocar de cena, "+ Token", "Excluir seleção".

## Testes (headless)
```
godot --headless --path . res://tests/test_net.tscn
godot --headless --path . res://tests/test_client.tscn
godot --headless --path . res://tests/test_menu.tscn
```

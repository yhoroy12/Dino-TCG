extends Control

# ==============================================================================
# modo_treino.gd — Controlador da Cena ModoTreino
# Gerencia seleção de adversário, expansão visual e seleção de dificuldade.
# ==============================================================================

const CENA_LOBBY   := "res://Scenes/Menus/Lobby.tscn"
const CENA_BATALHA := "res://Scenes/Battle/MesaJogador.tscn"

# -----------------------------------------------------------------------------
# REFERÊNCIAS ESTÁTICAS
# -----------------------------------------------------------------------------
@onready var button_voltar  : Button        = $MarginContainer/VBox/HBoxContainer/ButtonVoltar
@onready var grid           : GridContainer = $MarginContainer/VBox/GridContainer
@onready var panel_start    : PanelContainer = $MarginContainer/PanelContainer
@onready var button_start   : Button        = $MarginContainer/PanelContainer/MarginContainer/ButtonStart

# Os três adversários
@onready var rex    : PanelContainer = $MarginContainer/VBox/GridContainer/Rex
@onready var trike  : PanelContainer = $MarginContainer/VBox/GridContainer/Trike
@onready var raptor : PanelContainer = $MarginContainer/VBox/GridContainer/Raptor

# -----------------------------------------------------------------------------
# ESTADO INTERNO
# -----------------------------------------------------------------------------
# Qual adversário está selecionado agora (null = nenhum)
var _adversario_selecionado : PanelContainer = null

# Dificuldade escolhida pelo jogador
var _dificuldade : String = ""

# Guarda os size_flags originais de cada adversário para restaurar depois
# formato: { PanelContainer: { h: int, v: int } }
var _flags_originais : Dictionary = {}

# Lista dos três adversários para facilitar loops
var _adversarios : Array[PanelContainer] = []


# -----------------------------------------------------------------------------
# INICIALIZAÇÃO
# -----------------------------------------------------------------------------
func _ready() -> void:
	_adversarios = [rex, trike, raptor]

	# Salva os size_flags originais de cada adversário
	for adv in _adversarios:
		_flags_originais[adv] = {
			"h": adv.size_flags_horizontal,
			"v": adv.size_flags_vertical
		}

	button_voltar.pressed.connect(_on_voltar_pressed)
	button_start.pressed.connect(_on_start_pressed)
	panel_start.visible = false

	# Conecta o clique e os botões de dificuldade de cada adversário
	for adv in _adversarios:
		var texture := adv.get_node("TextureRect")
		texture.mouse_filter = Control.MOUSE_FILTER_STOP
		texture.gui_input.connect(_on_adversario_clicado.bind(adv))

		adv.get_node("actionoverlay/Vboxbutton/ButtonF").pressed.connect(
			func(): _on_dificuldade_selecionada(adv, "Facil")
		)
		adv.get_node("actionoverlay/Vboxbutton/ButtonM").pressed.connect(
			func(): _on_dificuldade_selecionada(adv, "Medio")
		)
		adv.get_node("actionoverlay/Vboxbutton/ButtonD").pressed.connect(
			func(): _on_dificuldade_selecionada(adv, "Dificil")
		)


# -----------------------------------------------------------------------------
# HANDLERS — NAVEGAÇÃO
# -----------------------------------------------------------------------------
func _on_voltar_pressed() -> void:
	get_tree().change_scene_to_file(CENA_LOBBY)


func _on_start_pressed() -> void:
	if _adversario_selecionado == null or _dificuldade == "":
		print("[ModoTreino] ❌ Adversário ou dificuldade não selecionados.")
		return

	var deck_ativo := DeckManager.obter_deck_ativo()
	if deck_ativo == "":
		print("[ModoTreino] ❌ Nenhum deck ativo encontrado. Defina um deck ativo no gerenciador.")
		return

	print("[ModoTreino] Iniciando treino — adversário: %s | dificuldade: %s | deck: %s" % [
		_adversario_selecionado.name,
		_dificuldade,
		deck_ativo
	])

	# Treino hoje é espelho do próprio deck do jogador — quando existir
	# um deck específico por adversário (Rex/Trike/Raptor), troca o
	# primeiro argumento por ele em vez de reusar deck_ativo.
	if not MatchData.preparar_partida_vs_ia(deck_ativo, _dificuldade, _adversario_selecionado.name):
		print("[ModoTreino] ❌ Falha ao preparar a partida.")
		return

	get_tree().change_scene_to_file(CENA_BATALHA)

# -----------------------------------------------------------------------------
# SELEÇÃO DE ADVERSÁRIO
# -----------------------------------------------------------------------------
func _on_adversario_clicado(event: InputEvent, adv: PanelContainer) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	# Se clicar no mesmo que já está selecionado, não faz nada
	if _adversario_selecionado == adv:
		return

	_selecionar_adversario(adv)


func _selecionar_adversario(adv: PanelContainer) -> void:
	_adversario_selecionado = adv
	_dificuldade = ""
	panel_start.visible = false

	for cada in _adversarios:
		if cada == adv:
			# Expande o selecionado para ocupar o máximo de espaço
			cada.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cada.size_flags_vertical   = Control.SIZE_EXPAND_FILL
			cada.get_node("actionoverlay").visible = true
		else:
			# Encolhe os outros — tamanho mínimo, sem expansão
			cada.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			cada.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
			cada.get_node("actionoverlay").visible = false


func _restaurar_todos() -> void:
	_adversario_selecionado = null
	_dificuldade = ""
	panel_start.visible = false

	for adv in _adversarios:
		adv.size_flags_horizontal = _flags_originais[adv]["h"]
		adv.size_flags_vertical   = _flags_originais[adv]["v"]
		adv.get_node("actionoverlay").visible = false


# -----------------------------------------------------------------------------
# SELEÇÃO DE DIFICULDADE
# -----------------------------------------------------------------------------
func _on_dificuldade_selecionada(adv: PanelContainer, dificuldade: String) -> void:
	_dificuldade = dificuldade
	panel_start.visible = true
	print("[ModoTreino] Adversário: %s | Dificuldade: %s" % [adv.name, dificuldade])


# -----------------------------------------------------------------------------
# CLIQUE FORA — RESTAURA OS TRÊS ADVERSÁRIOS
# -----------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if _adversario_selecionado == null:
		return

	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	# Verifica se o clique foi fora de todos os botões de dificuldade
	for adv in _adversarios:
		var overlay := adv.get_node("actionoverlay")
		if not overlay.visible:
			continue
		var bf : Button = overlay.get_node("Vboxbutton/ButtonF")
		var bm : Button = overlay.get_node("Vboxbutton/ButtonM")
		var bd : Button = overlay.get_node("Vboxbutton/ButtonD")
		var bs : Button = button_start

		var pos :Vector2 = event.global_position
		if bf.get_global_rect().has_point(pos): return
		if bm.get_global_rect().has_point(pos): return
		if bd.get_global_rect().has_point(pos): return
		if bs.get_global_rect().has_point(pos): return

	_restaurar_todos()

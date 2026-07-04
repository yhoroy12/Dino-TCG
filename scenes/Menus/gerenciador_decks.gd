extends Control

# ==============================================================================
# gerenciador_decks.gd — Controlador da Cena GerenciadorDecks
# Lista os decks salvos, gerencia deck ativo e navega para edição.
# ==============================================================================

const CENA_LOBBY       := "res://scenes/Lobby/Lobby.tscn"
const CENA_DECKBUILDER := "res://scenes/DeckBuilder/deckbuilder.tscn"
const CENA_FUNDO_CAPA  := "res://components/fundo_capa.tscn"

# -----------------------------------------------------------------------------
# REFERÊNCIAS DOS NÓS — ESTÁTICOS
# -----------------------------------------------------------------------------
@onready var button_voltar  : Button        = $MarginContainer/DuasColunas/StatusColuna/MarginContainer/VBoxContainer/ButtonVoltar
@onready var button_nv_deck : Button        = $MarginContainer/DuasColunas/DecksColuna/HeaderRow/ButtonNvDeck
@onready var grid_decks     : GridContainer = $MarginContainer/DuasColunas/DecksColuna/ScrollContainer/GridDecks

# Estatísticas do painel esquerdo
@onready var label_vitorias : Label = $MarginContainer/DuasColunas/StatusColuna/MarginContainer/VBoxContainer/StatusList/Vitoria/valor
@onready var label_derrotas : Label = $MarginContainer/DuasColunas/StatusColuna/MarginContainer/VBoxContainer/StatusList/Derrotas/valor
@onready var label_taxa     : Label = $MarginContainer/DuasColunas/StatusColuna/MarginContainer/VBoxContainer/StatusList/TxVitoria/valor

# -----------------------------------------------------------------------------
# ESTADO INTERNO
# -----------------------------------------------------------------------------
# Mantém referência a todos os FundoCapa instanciados para controle de overlay
var _cards_instanciados: Array[Control] = []


# -----------------------------------------------------------------------------
# INICIALIZAÇÃO
# -----------------------------------------------------------------------------
func _ready() -> void:
	button_voltar.pressed.connect(_on_voltar_pressed)
	button_nv_deck.pressed.connect(_on_novo_deck_pressed)
	_popular_grid()


func _popular_grid() -> void:
	# Limpa instâncias anteriores
	for filho in grid_decks.get_children():
		filho.queue_free()
	_cards_instanciados.clear()

	# CORREÇÃO DA LINHA 46: Tipagem explícita adicionada como Array
	var nomes_decks: Array = DeckManager.obter_lista_de_decks_salvos()

	if nomes_decks.is_empty():
		# Nenhum deck salvo ainda — pode exibir um placeholder se quiser
		return

	var cena_fundo_capa: PackedScene = load(CENA_FUNDO_CAPA)

	for nome in nomes_decks:
		# CORREÇÃO DA LINHA 55: Tipagem explícita adicionada como Dictionary
		var dados: Dictionary = DeckManager.carregar_deck_completo(nome)
		if dados.is_empty():
			continue

		var instancia: Control = cena_fundo_capa.instantiate()
		grid_decks.add_child(instancia)
		_cards_instanciados.append(instancia)

		# Aguarda o nó entrar na árvore antes de configurar
		await get_tree().process_frame
		instancia.configurar(dados)

		# Conecta os sinais do componente
		instancia.selecionado.connect(_on_card_selecionado)
		instancia.ativo_pressionado.connect(_on_ativo_pressionado)
		instancia.editar_pressionado.connect(_on_editar_pressionado)


# -----------------------------------------------------------------------------
# HANDLERS — NAVEGAÇÃO
# -----------------------------------------------------------------------------
func _on_voltar_pressed() -> void:
	get_tree().change_scene_to_file(CENA_LOBBY)


func _on_novo_deck_pressed() -> void:
	# Nenhum deck em edição — deckbuilder abre em branco
	if GameState.has_method("definir_deck_em_edicao"):
		GameState.definir_deck_em_edicao({})
	get_tree().change_scene_to_file(CENA_DECKBUILDER)


# -----------------------------------------------------------------------------
# HANDLERS — COMPONENTE FUNDO CAPA
# -----------------------------------------------------------------------------
func _on_card_selecionado(dados: Dictionary) -> void:
	# Fecha overlays de todos os outros cards antes de abrir o novo
	for card in _cards_instanciados:
		if card.has_method("fechar_overlay"):
			card.fechar_overlay()

	# Encontra o card que emitiu e abre o overlay dele
	for card in _cards_instanciados:
		# Compara pelo id único do deck
		if card._dados.get("id", "") == dados.get("id", ""):
			card.abrir_overlay()
			break

	_atualizar_estatisticas(dados)


func _on_ativo_pressionado(dados: Dictionary) -> void:
	var id_alvo: String = dados.get("id", "")

	# Remove ativo de todos os decks visualmente e no arquivo
	for card in _cards_instanciados:
		var dados_card: Dictionary = card._dados
		var era_ativo: bool = dados_card.get("ativo", false)

		if era_ativo:
			# Persiste a mudança no arquivo
			dados_card["ativo"] = false
			DeckManager.salvar_deck_completo(dados_card)

		card.marcar_ativo(false)

	# Marca o deck clicado como ativo
	for card in _cards_instanciados:
		var dados_card: Dictionary = card.get("_dados")
		if dados_card.get("id", "") == id_alvo:
			dados_card["ativo"] = true
			DeckManager.salvar_deck_completo(dados_card)
			card.marcar_ativo(true)
			card.fechar_overlay()
			break


func _on_editar_pressionado(dados: Dictionary) -> void:
	# Passa o deck para o GameState para o deckbuilder carregar
	if GameState.has_method("definir_deck_em_edicao"):
		GameState.definir_deck_em_edicao(dados)
	get_tree().change_scene_to_file(CENA_DECKBUILDER)


# -----------------------------------------------------------------------------
# ESTATÍSTICAS DO PAINEL ESQUERDO
# -----------------------------------------------------------------------------
func _atualizar_estatisticas(dados: Dictionary) -> void:
	# Tipagem explícita preventiva para evitar novos avisos de inferência
	var vitorias: int = int(dados.get("vitorias", 0))
	var derrotas: int = int(dados.get("derrotas", 0))
	var total: int    = vitorias + derrotas

	label_vitorias.text = str(vitorias)
	label_derrotas.text = str(derrotas)

	if total > 0:
		var taxa: float = float(vitorias) / float(total) * 100.0
		label_taxa.text = "%.1f%%" % taxa
	else:
		label_taxa.text = "—"


# -----------------------------------------------------------------------------
# FECHAR OVERLAY AO CLICAR FORA DE QUALQUER CARD
# -----------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	# Verifica se o clique foi fora de todos os cards instanciados
	var clicou_em_algum_card: bool = false
	for card in _cards_instanciados:
		if card.get_global_rect().has_point(event.global_position):
			clicou_em_algum_card = true
			break

	if not clicou_em_algum_card:
		for card in _cards_instanciados:
			if card.has_method("fechar_overlay"):
				card.fechar_overlay()

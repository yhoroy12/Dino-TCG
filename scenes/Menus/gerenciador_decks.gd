extends Control

# ==============================================================================
# gerenciador_decks.gd — Controlador da Interface de Lista de Decks
# ==============================================================================

const CENA_LOBBY       := "res://Scenes/Menus/Lobby.tscn"
const CENA_DECKBUILDER := "res://Scenes/Menus/deckbuilder.tscn"
const CENA_FUNDO_CAPA  := "res://Scenes/Components/fundo_capa.tscn"

@onready var button_voltar  : Button        = $MarginContainer/DuasColunas/StatusColuna/MarginContainer/VBoxContainer/ButtonVoltar
@onready var button_nv_deck : Button        = $MarginContainer/DuasColunas/DecksColuna/HeaderRow/ButtonNvDeck
@onready var grid_decks     : GridContainer = $MarginContainer/DuasColunas/DecksColuna/ScrollContainer/GridDecks

@onready var label_vitorias : Label = $MarginContainer/DuasColunas/StatusColuna/MarginContainer/VBoxContainer/StatusList/Vitoria/valor
@onready var label_derrotas : Label = $MarginContainer/DuasColunas/StatusColuna/MarginContainer/VBoxContainer/StatusList/Derrotas/valor
@onready var label_taxa     : Label = $MarginContainer/DuasColunas/StatusColuna/MarginContainer/VBoxContainer/StatusList/TxVitoria/valor

var _cards_instanciados: Array[Control] = []


func _ready() -> void:
	button_voltar.pressed.connect(_on_voltar_pressed)
	button_nv_deck.pressed.connect(_on_novo_deck_pressed)
	_popular_grid()


func _popular_grid() -> void:
	for filho in grid_decks.get_children():
		filho.queue_free()
	_cards_instanciados.clear()

	var nomes_decks := DeckManager.obter_lista_de_decks_salvos()
	if nomes_decks.is_empty(): return

	var cena_fundo_capa: PackedScene = load(CENA_FUNDO_CAPA)

	for nome in nomes_decks:
		var deck_data := DeckManager.carregar_deck(nome)
		if deck_data.id == "": continue

		var instancia = cena_fundo_capa.instantiate() as Control
		grid_decks.add_child(instancia)
		_cards_instanciados.append(instancia)

		await get_tree().process_frame
		
		# Compatibilidade visual: se o seu FundoCapa espera dicionário, passamos o dicionário do resource
		instancia.configurar(deck_data.para_dicionario())

		instancia.selecionado.connect(_on_card_selecionado)
		instancia.ativo_pressionado.connect(_on_ativo_pressionado)
		instancia.editar_pressionado.connect(_on_editar_pressionado)


func _on_voltar_pressed() -> void:
	get_tree().change_scene_to_file(CENA_LOBBY)


func _on_novo_deck_pressed() -> void:
	DeckManager.criar_novo_deck_para_edicao()
	get_tree().change_scene_to_file(CENA_DECKBUILDER)


func _on_card_selecionado(dados: Dictionary) -> void:
	for card in _cards_instanciados:
		if card.has_method("fechar_overlay"): card.fechar_overlay()

	for card in _cards_instanciados:
		if card._dados.get("id", "") == dados.get("id", ""):
			card.abrir_overlay()
			break

	_atualizar_estatisticas(dados)


func _on_ativo_pressionado(dados: Dictionary) -> void:
	var id_alvo: String = dados.get("id", "")
	
	# Passa a responsabilidade de gerenciar as flags e arquivos para o Manager
	DeckManager.definir_deck_ativo(id_alvo)
	
	# A UI apenas atualiza os estados visuais locais dos nós
	for card in _cards_instanciados:
		var card_id: String = card._dados.get("id", "")
		card.marcar_ativo(card_id == id_alvo)
		if card_id == id_alvo:
			card.fechar_overlay()


func _on_editar_pressionado(dados: Dictionary) -> void:
	var nome_deck: String = dados.get("nome", "")
	DeckManager.definir_deck_para_edicao(nome_deck)
	get_tree().change_scene_to_file(CENA_DECKBUILDER)


func _atualizar_estatisticas(dados: Dictionary) -> void:
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


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return

	var clicou_em_algum_card := false
	for card in _cards_instanciados:
		if card.get_global_rect().has_point(event.global_position):
			clicou_em_algum_card = true
			break

	if not clicou_em_algum_card:
		for card in _cards_instanciados:
			if card.has_method("fechar_overlay"): card.fechar_overlay()

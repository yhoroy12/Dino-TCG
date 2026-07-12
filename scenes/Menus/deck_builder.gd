extends MarginContainer

# ==============================================================================
# DeckBuilderUI — Controlador do Montador de Decks (scenes/deck_builder/deck_builder.gd)
# Rastreamento completo ativado por Logs.
# ==============================================================================

@onready var colecao_container: GridContainer = $MarginContainer/MainLayout/ContentArea/ColecaoPanel/VBoxColecao/ScrollColecao/ColecaoGrid
@onready var deck_container: VBoxContainer    = $MarginContainer/MainLayout/ContentArea/DeckPanel/VBox/DeckList/RowsContainer
@onready var card_holder: Control             = $MarginContainer/MainLayout/ContentArea/ZoomPanel/ZoomContent/CardHolder
@onready var nome_deck_input: LineEdit        = $MarginContainer/MainLayout/Topbar/ManeInput
@onready var contador_cartas_label: Label     = $MarginContainer/MainLayout/Topbar/CounterPill
@onready var mensagem_label: Label            = $MarginContainer/MainLayout/Topbar/AvisoBar/AvisoText
@onready var rule_text: Label  = $MarginContainer/MainLayout/ContentArea/ZoomPanel/ZoomContent/PanelContainer/VBoxContainer/RuleText
@onready var rule_text2: Label = $MarginContainer/MainLayout/ContentArea/ZoomPanel/ZoomContent/PanelContainer/VBoxContainer/RuleText2

const CENA_ANIMAL     = preload("res://Scenes/Components/card/Card.tscn")
const CENA_CATACLISMO = preload("res://Scenes/Components/card/CardEffect.tscn")
const CENA_TERRITORIO = preload("res://Scenes/Components/card/CardTerritorio.tscn")
const CENA_VESTIGIO   = preload("res://Scenes/Components/card/CardEffect.tscn")
const CENA_PRIMORDIAL = preload("res://Scenes/Components/card/CardForcaPrimordial.tscn")
const CENA_LOBBY      := "res://Scenes/Menus/Lobby.tscn"

const TAMANHO_ORIGINAL_CARTA := Vector2(450.0, 700.0)
const ESPACO_GRID := 1245
const NUM_COLUNAS := 6
const ESPACO_ENTRE_CARTAS := 5.0

# CardBaseResource (não CardResource): a coleção precisa incluir Animal
# (CardResource) e Energia/Vestígio/Cataclismo/Território (EffectResource)
# ao mesmo tempo — CardResource sozinho só aceitava Animal.
var colecao_cartas: Array[CardBaseResource] = []
var _deck_original_snapshot: Dictionary = {}


func _ready() -> void:
	print("--- [TRACKING LOG] Iniciando UI DeckBuilder _ready() ---")

	_caregar_catalogo_colecao()

	if DeckManager.deck_em_edicao == null:
		print("ℹ DeckManager.deck_em_edicao estava nulo. Criando um novo automaticamente.")
		DeckManager.criar_novo_deck_para_edicao()

	_deck_original_snapshot = DeckManager.deck_em_edicao.para_dicionario()
	print("ℹ Deck carregado para edição. Nome: ", DeckManager.deck_em_edicao.nome, " | Qtd cartas: ", DeckManager.deck_em_edicao.cartas.size())

	_atualizar_nome_input_ui()
	_popular_lista_deck_ui()
	_popular_grid_colecao_ui()
	print("--- [TRACKING LOG] Fim do _ready() ---")


## Antes só pegava CardDatabase.obter_catalogo_completo() (só Animal).
## Agora pega o catálogo combinado (Animal + Efeito) — é essa troca que
## faz Energia/Vestígio/Cataclismo/Território aparecerem na coleção.
func _caregar_catalogo_colecao() -> void:
	colecao_cartas.clear()
	print("🔍 Chamando CardDatabase.obter_catalogo_completo_tudo()...")
	var catalogo = CardDatabase.obter_catalogo_completo_tudo()

	if catalogo == null:
		print("❌ ERRO CRÍTICO: CardDatabase retornou NULL para o catálogo.")
		return

	print("ℹ CardDatabase retornou um dicionário com ", catalogo.keys().size(), " entradas brutas.")

	var contagem_validas := 0
	for id in catalogo:
		var carta = catalogo[id]
		if carta is CardBaseResource:
			colecao_cartas.append(carta)
			contagem_validas += 1
		else:
			print("⚠ Alerta: Entrada id '", id, "' no catálogo NÃO é do tipo CardBaseResource. É: ", typeof(carta))

	print("📊 Filtro concluído: ", contagem_validas, " instâncias válidas adicionadas em 'colecao_cartas'.")


func _atualizar_nome_input_ui() -> void:
	if nome_deck_input:
		nome_deck_input.text = DeckManager.deck_em_edicao.nome
		if not nome_deck_input.text_changed.is_connected(_on_nome_deck_changed):
			nome_deck_input.text_changed.connect(_on_nome_deck_changed)


func _on_nome_deck_changed(novo_nome: String) -> void:
	DeckManager.deck_em_edicao.nome = novo_nome.strip_edges()


func _popular_grid_colecao_ui() -> void:
	print("📦 Iniciando renderização da Grid de Coleção...")

	if colecao_container == null:
		print("❌ ERRO DE REFERÊNCIA: 'colecao_container' (GridContainer) está NULO no script. Verifique o caminho na árvore de nós.")
		return

	var filhos_removidos := colecao_container.get_child_count()
	for child in colecao_container.get_children():
		child.queue_free()
	print("🧹 Grid limpa. Nós antigos removidos: ", filhos_removidos)

	if colecao_cartas.is_empty():
		print("❌ ABORTO: 'colecao_cartas' está vazia, o loop não vai rodar.")
		return

	var instanciadas_com_sucesso := 0
	for card_resource in colecao_cartas:
		var card_visual = _instanciar_carta_visual(card_resource)
		if card_visual:
			var slot_envelope = Control.new()
			colecao_container.add_child(slot_envelope)
			slot_envelope.add_child(card_visual)

			if card_visual.has_method("inicializar"):
				card_visual.inicializar(card_resource)

			_conectar_sinais_carta(card_visual)
			_aplicar_escala_grid(card_visual, slot_envelope)
			instanciadas_com_sucesso += 1

	print("✅ Fim da população. Cartas instanciadas e adicionadas na árvore visível: ", instanciadas_com_sucesso)


func _instanciar_carta_visual(card_resource: CardBaseResource) -> Control:
	if not card_resource:
		print("❌ Erro interno no loop: O card_resource fornecido está NULO.")
		return null

	var super_type = _obter_super_type(card_resource)
	var cena_carta = _obter_cena_por_tipo(super_type)

	if not cena_carta:
		print("❌ Erro: Nenhuma PackedScene mapeada para o tipo: ", super_type, " (Carta: ", card_resource.name, ")")
		return null

	var instancia = cena_carta.instantiate()
	if not instancia:
		print("❌ Erro Crítico: .instantiate() falhou para a cena do caminho: ", cena_carta.resource_path)
		return null

	var card_visual = instancia as Control
	if not card_visual:
		print("❌ Erro de herança: Raiz da cena '", cena_carta.resource_path, "' NÃO herda de Control! Classe real: ", instancia.get_class())
		instancia.queue_free()
		return null

	# Atribuição dinâmica: cada cena (card.gd, card_effecct.gd,
	# CardForcaPrimordial.gd, CardTerritorio.gd) já declara seu próprio
	# "recurso_carta" tipado (CardResource ou EffectResource). Como aqui
	# escolhemos a cena certa via _obter_cena_por_tipo(), o tipo runtime
	# de card_resource sempre bate com o que a cena espera.
	card_visual.recurso_carta = card_resource
	return card_visual


func _aplicar_escala_grid(card_visual: Control, slot_envelope: Control) -> void:
	var espaco_total_margem = ESPACO_ENTRE_CARTAS * (NUM_COLUNAS - 1)
	var largura_por_coluna = (ESPACO_GRID - espaco_total_margem) / NUM_COLUNAS
	var proporcao = TAMANHO_ORIGINAL_CARTA.y / TAMANHO_ORIGINAL_CARTA.x
	var altura_por_coluna = largura_por_coluna * proporcao
	var escala_necessaria = largura_por_coluna / TAMANHO_ORIGINAL_CARTA.x

	slot_envelope.custom_minimum_size = Vector2(largura_por_coluna, altura_por_coluna)

	card_visual.position = Vector2.ZERO
	card_visual.pivot_offset = Vector2.ZERO
	card_visual.scale = Vector2(escala_necessaria, escala_necessaria)
	card_visual.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card_visual.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_visual.size = TAMANHO_ORIGINAL_CARTA


func _conectar_sinais_carta(card_visual: Control) -> void:
	if card_visual.has_signal("clicado") and not card_visual.clicado.is_connected(_on_card_colecao_clicado):
		card_visual.clicado.connect(_on_card_colecao_clicado)
	if card_visual.has_signal("hovered") and not card_visual.hovered.is_connected(_on_card_colecao_hovered):
		card_visual.hovered.connect(_on_card_colecao_hovered)


func _on_card_colecao_clicado(nodo_carta: Control, botao: int) -> void:
	var card_res = nodo_carta.get("recurso_carta") as CardBaseResource
	if not card_res: return

	if botao == MOUSE_BUTTON_LEFT:
		_tentar_adicionar_carta(card_res)
	elif botao == MOUSE_BUTTON_RIGHT:
		_tentar_remover_carta(card_res)


func _on_card_colecao_hovered(card_res: CardBaseResource) -> void:
	_exibir_zoom_carta(card_res)


func _tentar_adicionar_carta(card_res: CardBaseResource) -> void:
	var deck = DeckManager.deck_em_edicao

	if deck.cartas.size() >= DeckRulesSystem.TAMANHO_DECK_VALIDO:
		_exibir_mensagem("Deck cheio! Limite de %d cartas." % DeckRulesSystem.TAMANHO_DECK_VALIDO, true)
		return

	var limite = DeckRulesSystem.obter_limite_copias(card_res)
	var copias_atuais = DeckRulesSystem.contar_copias(deck.cartas, card_res.id)

	if copias_atuais >= limite:
		_exibir_mensagem("Limite de %d cópias de '%s' atingido!" % [limite, card_res.name], true)
		return

	deck.cartas.append(card_res.duplicate() as CardBaseResource)
	_popular_lista_deck_ui()


func _tentar_remover_carta(card_res: CardBaseResource) -> void:
	var deck = DeckManager.deck_em_edicao
	var index_remover := -1

	for i in range(deck.cartas.size() -1, -1, -1):
		if deck.cartas[i].id == card_res.id:
			index_remover = i
			break

	if index_remover != -1:
		deck.cartas.remove_at(index_remover)
		_popular_lista_deck_ui()
	else:
		_exibir_mensagem("Essa carta não está no seu deck.", true)


func _popular_lista_deck_ui() -> void:
	for filho in deck_container.get_children():
		filho.queue_free()

	var agrupadas: Dictionary = {}
	for carta in DeckManager.deck_em_edicao.cartas:
		if agrupadas.has(carta.id):
			agrupadas[carta.id]["qtd"] += 1
		else:
			agrupadas[carta.id] = {"dados": carta, "qtd": 1}

	for id in agrupadas:
		var item = agrupadas[id]
		var dados_carta = item["dados"] as CardBaseResource
		var qtd = item["qtd"]

		var linha = Label.new()
		linha.text = _formatar_linha_deck(dados_carta, qtd)
		linha.mouse_filter = Control.MOUSE_FILTER_STOP
		linha.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		deck_container.add_child(linha)
		linha.mouse_entered.connect(_exibir_zoom_carta.bind(dados_carta))
		linha.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_LEFT: _tentar_adicionar_carta(dados_carta)
				elif ev.button_index == MOUSE_BUTTON_RIGHT: _tentar_remover_carta(dados_carta)
		)

	_atualizar_labels_validacao()


func _atualizar_labels_validacao() -> void:
	var deck = DeckManager.deck_em_edicao
	var resultado = DeckRulesSystem.validar_deck(deck)

	if contador_cartas_label:
		contador_cartas_label.text = "Cartas: %d / %d" % [deck.cartas.size(), DeckRulesSystem.TAMANHO_DECK_VALIDO]

	_colorir_regra(rule_text, resultado["tamanho_valido"])
	_colorir_regra(rule_text2, resultado["possui_filhote"])


func _exibir_zoom_carta(card_res: CardBaseResource) -> void:
	if not card_res or not card_holder: return
	for filho in card_holder.get_children(): filho.queue_free()

	var cena = _obter_cena_por_tipo(_obter_super_type(card_res))
	if not cena: return

	var card_visual = cena.instantiate() as Control
	card_holder.add_child(card_visual)
	await get_tree().process_frame
	if card_visual.has_method("inicializar"): card_visual.inicializar(card_res)
	card_visual.position = Vector2.ZERO
	card_visual.scale = Vector2(0.8, 0.8)


func _on_btn_save_pressed() -> void:
	var deck = DeckManager.deck_em_edicao

	if deck.nome.strip_edges() == "":
		_exibir_mensagem("Erro: Digite um nome válido.", true)
		return
	if deck.cartas.is_empty():
		_exibir_mensagem("Erro: Impossível salvar baralho vazio.", true)
		return

	var validacao = DeckRulesSystem.validar_deck(deck)
	if not validacao["valido"]:
		_exibir_mensagem("Erro: O deck viola regras obrigatórias!", true)
		return

	if DeckManager.salvar_deck(deck):
		_deck_original_snapshot = deck.para_dicionario()
		_exibir_mensagem("Deck salvo com sucesso!", false)
	else:
		_exibir_mensagem("Erro interno ao salvar arquivo.", true)


func _on_btn_cancel_pressed() -> void:
	if DeckManager.deck_em_edicao.para_dicionario() != _deck_original_snapshot:
		print("⚠ Modificações descartadas")
	get_tree().change_scene_to_file(CENA_LOBBY)


func _formatar_linha_deck(dados: CardBaseResource, quantidade: int) -> String:
	var stage_val = dados.get("stage") if dados.get("stage") != null else dados.get("estagio")
	var estagio = str(stage_val if stage_val != null else "").strip_edges().to_lower()
	var prefixo = "F" if "filhote" in estagio else "J" if "jovem" in estagio else "A" if "adulto" in estagio else ""
	return "%s %s x%d" % [prefixo, dados.name, quantidade] if prefixo != "" else "%s x%d" % [dados.name, quantidade]

func _obter_super_type(card_resource: CardBaseResource) -> String:
	var s_type = card_resource.get("super_type") if card_resource.get("super_type") != null else card_resource.get("categoria")
	return str(s_type if s_type != null else "animal").to_lower().strip_edges()

func _obter_cena_por_tipo(tipo: String) -> PackedScene:
	match tipo:
		"animal": return CENA_ANIMAL
		"cataclismo", "evento": return CENA_CATACLISMO
		"territorio", "território": return CENA_TERRITORIO
		"vestigio", "vestígio": return CENA_VESTIGIO
		_: return CENA_PRIMORDIAL if "primordial" in tipo or "energia" in tipo else CENA_ANIMAL

func _exibir_mensagem(texto: String, erro: bool = false) -> void:
	if not mensagem_label: return
	mensagem_label.get_parent().visible = true
	mensagem_label.text = texto
	var cor = Color(1, 0.3, 0.3) if erro else Color(0.3, 1, 0.3)
	mensagem_label.add_theme_color_override("font_color", cor)

func _colorir_regra(label: Label, valida: bool) -> void:
	if label: label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3) if valida else Color(1.0, 0.3, 0.3))

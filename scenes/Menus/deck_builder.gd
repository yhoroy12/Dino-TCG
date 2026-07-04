extends MarginContainer

# ==============================================================================
# DeckBuilderUI — Controlador do Montador de Decks (scenes/deck_builder/deck_builder.gd)
# Gerencia a interface de montagem, filtros e validação estrita de baralhos.
# ==============================================================================

# ============================================================================
# REFERÊNCIAS AOS NÓS DA UI
# ============================================================================
@onready var colecao_container: GridContainer = $MarginContainer/MainLayout/ContentArea/ColecaoPanel/VBoxColecao/ScrollColecao/ColecaoGrid
@onready var deck_container: VBoxContainer    = $MarginContainer/MainLayout/ContentArea/DeckPanel/VBox/DeckList/RowsContainer
@onready var card_holder: Control             = $MarginContainer/MainLayout/ContentArea/ZoomPanel/ZoomContent/CardHolder
@onready var nome_deck_input: LineEdit        = $MarginContainer/MainLayout/Topbar/ManeInput
@onready var contador_cartas_label: Label     = $MarginContainer/MainLayout/Topbar/CounterPill
@onready var mensagem_label: Label            = $MarginContainer/MainLayout/Topbar/AvisoBar/AvisoText
@onready var rule_text: Label  = $MarginContainer/MainLayout/ContentArea/ZoomPanel/ZoomContent/PanelContainer/VBoxContainer/RuleText
@onready var rule_text2: Label = $MarginContainer/MainLayout/ContentArea/ZoomPanel/ZoomContent/PanelContainer/VBoxContainer/RuleText2

# ============================================================================
# CENAS DE CARTAS (por tipo)
# ============================================================================
const CENA_ANIMAL     = preload("res://components/card/Card.tscn")
const CENA_CATACLISMO = preload("res://components/card/CardEffect.tscn")
const CENA_TERRITORIO = preload("res://components/card/CardTerritorio.tscn")
const CENA_VESTIGIO   = preload("res://components/card/CardEffect.tscn")
const CENA_PRIMORDIAL = preload("res://components/card/CardForcaPrimordial.tscn")

# ============================================================================
# CENAS DE NAVEGAÇÃO
# ============================================================================
const CENA_LOBBY := "res://scenes/Lobby/Lobby.tscn"

# ============================================================================
# CONFIGURAÇÕES DE ESCALA 
# ============================================================================
# Tamanho original das cartas
const TAMANHO_ORIGINAL_CARTA := Vector2(450.0, 700.0)

# Escala que será aplicada (45% = 0.45)
const ESCALA_COLECAO := 0.45

# Espaço disponível na grid (760px)
const ESPACO_GRID := 1245

# Número de colunas na grid
const NUM_COLUNAS := 6

# Espaçamento entre cartas (5px)
const ESPACO_ENTRE_CARTAS := 5.0

# ============================================================================
# VARIÁVEIS DE ESTADO
# ============================================================================
var nome_do_deck_atual: String = ""

# Dados do deck em construção
var deck_cartas: Array[CardResource] = []
var colecao_cartas: Array[CardResource] = []

# Dados do deck original (se estiver editando)
var _deck_original: Dictionary = {}

# UI atual
var _carta_zoom_atual: Control = null


# ============================================================================
# INICIALIZAÇÃO
# ============================================================================
func _ready() -> void:
		
	# Carrega o catálogo de cartas
	_caregar_colecao()
	# Verifica se está editando um deck existente
	_carregar_deck_em_edicao()
	_popular_deck()
	# Inicializa a interface
	_atualizar_nome_deck_input()
	# Popula a grid com as cartas
	_popular_colecao()

# ============================================================================
# CARREGAMENTO DE DADOS
# ============================================================================
func _caregar_colecao() -> void:
	"""Carrega o catálogo completo de cartas do CardDatabase"""
	colecao_cartas.clear()
	
	var catalogo = CardDatabase.obter_catalogo_completo()
	
	if catalogo == null:
		push_error("CardDatabase retornou null")
		return
	
	for carta in catalogo.values():
		if carta is CardResource:
			colecao_cartas.append(carta)
	
	print("✓ Carregadas %d cartas do catálogo" % colecao_cartas.size())

func _carregar_deck_em_edicao() -> void:
	"""Verifica se há um deck em edição e carrega seus dados"""
	_deck_original = GameState.consumir_deck_em_edicao()
	
	if _deck_original.is_empty():
		# Modo novo deck
		nome_do_deck_atual = "MeuNovoDeck"
		deck_cartas.clear()
		print("✓ Modo: Novo Deck")
	else:
		# Modo edição
		nome_do_deck_atual = _deck_original.get("nome", "MeuNovoDeck")
		_reconstruir_deck_cartas(_deck_original.get("colecao", []))
		print("✓ Modo: Editar Deck '%s'" % nome_do_deck_atual)

func _reconstruir_deck_cartas(colecao: Array) -> void:
	"""Reconstrói o array deck_cartas a partir do JSON salvo"""
	deck_cartas.clear()
	
	for entrada in colecao:
		var id: String = str(entrada.get("id", ""))
		var quantidade: int = int(entrada.get("quantidade", 1))
		
		var dados_carta = CardDatabase.obter_carta(id)
		
		if dados_carta == null:
			push_warning("Carta '%s' não encontrada no CardDatabase" % id)
			continue
		
		for _i in range(quantidade):
			deck_cartas.append(dados_carta.duplicate() as CardResource)

# ============================================================================
# ATUALIZAÇÃO DA UI
# ============================================================================
func _atualizar_nome_deck_input() -> void:
	"""Sincroniza o input de nome com a variável interna"""
	if nome_deck_input:
		nome_deck_input.text = nome_do_deck_atual
		
		if not nome_deck_input.text_changed.is_connected(_on_nome_deck_changed):
			nome_deck_input.text_changed.connect(_on_nome_deck_changed)

func _on_nome_deck_changed(novo_nome: String) -> void:
	"""Callback: nome do deck foi alterado"""
	nome_do_deck_atual = novo_nome.strip_edges()

# ============================================================================
# POPULAÇÃO DA GRID DE COLEÇÃO
# ============================================================================
func _popular_colecao() -> void:
	"""Popula a grid com as cartas da coleção"""
	print("\n=== POPULANDO COLEÇÃO ===")
	
	# Remove todas as cartas antigas
	for child in colecao_container.get_children():
		child.queue_free()
	
	# Aguarda um frame para garantir que foram removidas
	await get_tree().process_frame
	
	print("Instanciando %d cartas..." % colecao_cartas.size())
	
	# Instancia cada carta e adiciona à grid
	for card_resource in colecao_cartas:
		var card_visual = _instanciar_carta(card_resource)
		
		if card_visual == null:
			push_error("Falha ao instanciar carta: %s" % card_resource.name)
			continue
		
		# ADICIONA À GRID PRIMEIRO
		colecao_container.add_child(card_visual)
		
		# AGUARDA UM FRAME para garantir que _ready() foi chamado
		await get_tree().process_frame
		
		# AGORA INICIALIZA (a carta já está na árvore)
		if card_visual.has_method("inicializar"):
			card_visual.inicializar(card_resource)
		
		# Conecta sinais de interação
		_conectar_sinais_carta(card_visual)
		
		# APLICA A ESCALA
		_adicionar_carta_na_grid(card_visual)
	
	print("✓ Grid populada com sucesso")

func _instanciar_carta(card_resource: CardResource) -> Control:
	"""Instancia a cena correta baseado no super_type da carta"""
	
	# Obtém o super_type da carta (animal, cataclismo, território, vestígio, primordial)
	var super_type = _obter_super_type(card_resource)
	
	# Seleciona a cena correta baseado no tipo
	var cena_carta = _obter_cena_por_tipo(super_type)
	
	if cena_carta == null:
		push_error("Nenhuma cena definida para tipo: %s" % super_type)
		return null
	
	# Instancia a cena
	var card_visual = cena_carta.instantiate() as Control
	
	if card_visual == null:
		push_error("Falha ao instanciar cena de carta para tipo: %s" % super_type)
		return null
	
	# Define o resource da carta na instância visual
	card_visual.recurso_carta = card_resource
	
	print("  ✓ Instanciada: %s (tipo: %s)" % [card_resource.name, super_type])
	
	return card_visual

# ============================================================================
# ESCALA DAS CARTAS (FUNÇÃO SEPARADA)
# ============================================================================
func _adicionar_carta_na_grid(card_visual: Control) -> void:
	"""Aplica escala e cria o envelope para a carta não quebrar a grid"""
	
	# 1. CALCULA OS TAMANHOS (Baseado no tamanho da sua grid e da sua carta)
	var espaco_total_margem = ESPACO_ENTRE_CARTAS * (NUM_COLUNAS - 1)
	var largura_por_coluna = (ESPACO_GRID - espaco_total_margem) / NUM_COLUNAS
	
	# Mantém a proporção da altura (700 / 450)
	var proporcao = TAMANHO_ORIGINAL_CARTA.y / TAMANHO_ORIGINAL_CARTA.x
	var altura_por_coluna = largura_por_coluna * proporcao
	
	# Calcula a porcentagem de escala necessária
	var escala_necessaria = largura_por_coluna / TAMANHO_ORIGINAL_CARTA.x

	# 2. CRIA O ENVELOPE (O Slot invisível)
	var slot_envelope = Control.new()
	slot_envelope.custom_minimum_size = Vector2(largura_por_coluna, altura_por_coluna)
	slot_envelope.clip_contents = false # Garante que nada seja cortado nas bordas
	
	# 3. COLOCA O ENVELOPE NO LUGAR DA CARTA
	# Pega o container pai (colecao_container)
	var pai = card_visual.get_parent()
	
	# Adiciona o envelope na grid
	pai.add_child(slot_envelope)
	
	# Move o envelope para a mesma posição do índice da carta na árvore de nós
	# Isso garante que a ordem das cartas na coleção não mude
	pai.move_child(slot_envelope, card_visual.get_index())
	
	# 4. TRANSERE A CARTA PARA DENTRO DO ENVELOPE
	card_visual.reparent(slot_envelope)
	
	# CORREÇÃO CRÍTICA: Zera a posição da carta dentro do envelope.
	# Sem isso, ela herda posições antigas e gera o efeito "escada".
	card_visual.position = Vector2.ZERO

	# 5. APLICA A ESCALA E TRAVA O TAMANHO
	card_visual.pivot_offset = Vector2.ZERO
	card_visual.scale = Vector2(escala_necessaria, escala_necessaria)
	
	# Força as flags a não tentarem esticar a carta além do 450x700 original
	card_visual.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card_visual.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_visual.size = TAMANHO_ORIGINAL_CARTA
	
	print("  ✓ Escala e Envelope aplicados: %.0f%% (Slot: %.0fx%.0f)" % [
		escala_necessaria * 100, largura_por_coluna, altura_por_coluna
	])

func _obter_super_type(card_resource: CardResource) -> String:
	"""Obtém o super_type da carta de forma segura"""
	var super_type = card_resource.get("super_type")
	
	if super_type == null:
		super_type = card_resource.get("categoria")
	
	var tipo = str(super_type if super_type != null else "animal").to_lower().strip_edges()
	return tipo
 
func _obter_cena_por_tipo(tipo: String) -> PackedScene:
	"""Retorna a cena correta baseado no tipo da carta"""
	match tipo:
		"animal":
			return CENA_ANIMAL
		"cataclismo", "evento":
			return CENA_CATACLISMO
		"territorio", "território":
			return CENA_TERRITORIO
		"vestigio", "vestígio":
			return CENA_VESTIGIO
		"energia", "primordial":
			return CENA_PRIMORDIAL
		_:
			if "primordial" in tipo:
				return CENA_PRIMORDIAL
			return CENA_ANIMAL
 
func _conectar_sinais_carta(card_visual: Control) -> void:
	"""Conecta os sinais de interação da carta"""
	# Verifica se a carta tem o sinal 'clicado'
	if card_visual.has_signal("clicado"):
		if not card_visual.clicado.is_connected(_on_card_colecao_clicado):
			card_visual.clicado.connect(_on_card_colecao_clicado)
	
	# Verifica se a carta tem o sinal 'hovered'
	if card_visual.has_signal("hovered"):
		if not card_visual.hovered.is_connected(_on_card_colecao_hovered):
			card_visual.hovered.connect(_on_card_colecao_hovered)
 
# ============================================================================
# INTERAÇÕES COM CARTAS DA COLEÇÃO
# ============================================================================
func _on_card_colecao_clicado(nodo_carta: Control, botao: int) -> void:
	"""Callback: uma carta da coleção foi clicada"""
	var card_res = nodo_carta.get("recurso_carta") as CardResource
	
	if card_res == null:
		push_error("Carta clicada não tem recurso_carta")
		return
	
	print("Clique em: %s (botão: %d)" % [card_res.name, botao])
	
	# Botão direito: remove do deck
	if botao == MOUSE_BUTTON_RIGHT:
		_remover_carta_do_deck(card_res)
		return
	
	# Botão esquerdo: adiciona ao deck
	if botao == MOUSE_BUTTON_LEFT:
		_adicionar_carta_ao_deck(card_res)
		return
  
func _on_card_colecao_hovered(card_res: CardResource) -> void:
	"""Callback: mouse entrou em uma carta da coleção"""
	_exibir_zoom_carta(card_res)
  
func _adicionar_carta_ao_deck(card_res: CardResource) -> void:
	"""Adiciona uma cópia da carta ao deck"""
	if card_res == null:
		return
	
	# Verifica se o deck já está cheio
	if deck_cartas.size() >= DeckManager.TAMANHO_DECK_VALIDO:
		_exibir_mensagem("Deck cheio! Limite de %d cartas." % DeckManager.TAMANHO_DECK_VALIDO, true)
		return
	
	# Verifica limite de cópias
	var limite = _obter_limite_copias(card_res)
	var copias_atuais = _contar_copias_no_deck(card_res.id)
	
	if copias_atuais >= limite:
		_exibir_mensagem("Limite de %d cópias de '%s' atingido!" % [limite, card_res.name], true)
		return
	
	# Adiciona ao deck
	deck_cartas.append(card_res.duplicate() as CardResource)
	_popular_deck()
	
	print("✓ Adicionada: %s ao deck (total: %d)" % [card_res.name, deck_cartas.size()])
  
func _remover_carta_do_deck(card_res: CardResource) -> void:
	"""Remove uma cópia da carta do deck"""
	if card_res == null:
		return
	
	# Verifica se existe no deck
	var tem_no_deck = deck_cartas.any(func(c): return c.id == card_res.id)
	
	if not tem_no_deck:
		_exibir_mensagem("Essa carta não está no seu deck.", true)
		return
	
	# Remove a primeira ocorrência
	for i in range(deck_cartas.size() - 1, -1, -1):
		if deck_cartas[i].id == card_res.id:
			deck_cartas.remove_at(i)
			break
	
	_popular_deck()
	
	print("✓ Removida: %s do deck (total: %d)" % [card_res.name, deck_cartas.size()])
  
func _obter_limite_copias(card_res: CardResource) -> int:
	# Limite específico definido na carta
	var limite_val = card_res.get("limite_copias")
	if limite_val != null:
		return int(limite_val)

	# Energias não possuem limite de 4 cópias
	var super_type := str(card_res.get("super_type")).strip_edges().to_lower()

	if super_type == "energia":
		return 99

	# Limite padrão
	return 4
  
func _contar_copias_no_deck(card_id: String) -> int:
	"""Conta quantas cópias de uma carta estão no deck"""
	var total = 0
	for carta in deck_cartas:
		if carta.id == card_id:
			total += 1
	return total
  
# ============================================================================
# POPULAÇÃO DO DECK (LISTA DE CARTAS ADICIONADAS)
# ============================================================================
func _popular_deck() -> void:
	
	"""Popula a lista de cartas adicionadas ao deck"""
	# Remove todas as linhas antigas
	for filho in deck_container.get_children():
		filho.queue_free()
	
	# Agrupa cartas por ID
	var cartas_agrupadas: Dictionary = {}
	for dados in deck_cartas:
		var id = dados.id
		if cartas_agrupadas.has(id):
			cartas_agrupadas[id]["qtd"] += 1
		else:
			cartas_agrupadas[id] = {"dados": dados, "qtd": 1}
	
	# Cria uma linha para cada carta única
	for id in cartas_agrupadas:
		var item = cartas_agrupadas[id]
		var dados_carta = item["dados"] as CardResource
		var quantidade = item["qtd"]
		
		var linha = Label.new()
		linha.text = _formatar_linha_deck(dados_carta, quantidade)
		linha.tooltip_text = dados_carta.name
		linha.mouse_filter = Control.MOUSE_FILTER_STOP
		linha.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		deck_container.add_child(linha)
		
		# Conecta sinais de interação
		linha.mouse_entered.connect(_on_linha_deck_mouse_entered.bind(dados_carta))
		linha.gui_input.connect(_on_linha_deck_input.bind(dados_carta))
	
	# Atualiza o contador de cartas
	_atualizar_contador_cartas()
	
	# Valida as regras
	verificar_regras_do_deck()

func _formatar_linha_deck(dados: CardResource, quantidade: int) -> String:
	"""Formata o texto de uma linha do deck"""
	var nome = dados.name
	
	# Obtém o estágio (abreviado)
	var stage_val = dados.get("stage") if dados.get("stage") != null else dados.get("estagio")
	var prefixo = _abreviar_estagio(stage_val if stage_val != null else "")
	
	if prefixo != "":
		return "%s %s x%d" % [prefixo, nome, quantidade]
	return "%s x%d" % [nome, quantidade]
  
func _abreviar_estagio(estagio_bruto) -> String:
	"""Abrevia o estágio em uma letra"""
	var estagio = str(estagio_bruto).strip_edges().to_lower()
	match estagio:
		"filhote":
			return "F"
		"jovem":
			return "J"
		"adulto":
			return "A"
		_:
			return ""
  

  
func _on_linha_deck_input(event: InputEvent, dados_alvo: CardResource) -> void:
	"""Callback: entrada em uma linha do deck"""
	if not (event is InputEventMouseButton and event.pressed):
		return
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		_adicionar_carta_ao_deck(dados_alvo)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_remover_carta_do_deck(dados_alvo)

# ============================================================================
# ZOOM DA CARTA PARA LEITURA.
# ============================================================================
# ==
#	NESSA  AREA DEVE SER INSERIDO A MECANICA ONDE QUANDO O JOGADOR DEIXAR O
#   MOUSE POR CIMA DA CARTA ELA AUMENTE O TAMANHO (DEIXAR OS VALORES MARCADOS 
#   PARA QUE EU POSSA VERIFICAR OS CALCULO COMO UMA EXPORTVAR) PARA FACILITAR A
#   LEITURA DELA.
# OS SIGNALS DE MOUSE ENTERED
func _on_linha_deck_mouse_entered(dados_carta: CardResource) -> void:
	"""Callback: mouse entrou em uma linha do deck"""
	_exibir_zoom_carta(dados_carta)

func _exibir_zoom_carta(card_res: CardResource) -> void:
	if card_res == null or card_holder == null:
		return
	
	for filho in card_holder.get_children():
		filho.queue_free()
	
	var cena_carta = _obter_cena_por_tipo(_obter_super_type(card_res))
	if cena_carta == null:
		return
	
	var card_visual = cena_carta.instantiate() as Control
	if card_visual == null:
		return
	
	card_holder.add_child(card_visual)
	_carta_zoom_atual = card_visual
	
	await get_tree().process_frame
	
	if card_visual.has_method("inicializar"):
		card_visual.inicializar(card_res)
	
	card_visual.position = Vector2.ZERO
	card_visual.scale = Vector2(0.8, 0.8)
	card_visual.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
# ============================================================================
# ATUALIZAÇÃO DO CONTADOR
# ============================================================================
func _atualizar_contador_cartas() -> void:
	"""Atualiza o contador de cartas no topo"""
	if contador_cartas_label:
		contador_cartas_label.text = "Cartas: %d / %d" % [deck_cartas.size(), DeckManager.TAMANHO_DECK_VALIDO]
  
# ============================================================================
# BOTÕES DE AÇÃO - SALVAR
# ============================================================================
func _on_btn_save_pressed():
	"""Callback: botão Salvar foi pressionado"""
	print("\n=== SALVANDO DECK ===")
	
	# Validações básicas
	if not _validar_nome_deck():
		return
	
	if not _validar_deck_nao_vazio():
		return
	
	if not _validar_regras_do_deck():
		return
	
	# Monta o objeto de dados do deck
	var dados_completos = _montar_dados_deck()
	
	# Salva no DeckManager
	var sucesso = DeckManager.salvar_deck_completo(dados_completos)
	
	if sucesso:
		_deck_original = dados_completos.duplicate(true)
		_exibir_mensagem("Deck '%s' salvo com sucesso!" % nome_do_deck_atual, false)
		print("✓ Deck salvo com sucesso")
	else:
		_exibir_mensagem("Erro ao salvar o deck. Tente novamente.", true)
		print("✗ Erro ao salvar deck")
 
func _validar_nome_deck() -> bool:
	"""Valida se o nome do deck é válido"""
	if nome_do_deck_atual.strip_edges() == "":
		_exibir_mensagem("Erro: Digite um nome válido para o seu deck.", true)
		return false
	return true
 
func _validar_deck_nao_vazio() -> bool:
	"""Valida se o deck não está vazio"""
	if deck_cartas.is_empty():
		_exibir_mensagem("Erro: Impossível salvar um baralho vazio.", true)
		return false
	return true
 
func _validar_regras_do_deck() -> bool:
	"""Valida se o deck segue as regras obrigatórias"""
	if not verificar_regras_do_deck():
		_exibir_mensagem("Erro: O deck viola as regras obrigatórias!", true)
		return false
	return true
 
func _montar_dados_deck() -> Dictionary:
	"""Monta o dicionário com os dados do deck para salvar"""
	# Agrupa cartas por ID contando quantidades
	var agrupado: Dictionary = {}
	for carta in deck_cartas:
		var id_carta: String = carta.id.strip_edges()
		if id_carta == "": continue
		agrupado[id_carta] = agrupado.get(id_carta, 0) + 1
	
	# Converte para formato de array para JSON
	var colecao: Array = []
	for id in agrupado:
		colecao.append({"id": id, "quantidade": agrupado[id]})
	
	# Monta os dados completos preservando informações do deck original
	var dados := {
		"id":       _deck_original.get("id", ""),
		"nome":     nome_do_deck_atual,
		"ativo":    _deck_original.get("ativo", false),
		"capa":     _deck_original.get("capa", ""),
		"colecao":  colecao,
		"vitorias": _deck_original.get("vitorias", 0),
		"derrotas": _deck_original.get("derrotas", 0),
	}
	
	return dados

# ============================================================================
# BOTÕES DE AÇÃO - CANCELAR
# ============================================================================
func _on_btn_cancel_pressed():
	"""Callback: botão Cancelar foi pressionado"""
	print("\n=== CANCELANDO EDIÇÃO ===")
	
	# Se há mudanças não salvas, avisa o usuário
	if _tem_mudancas_nao_salvas():
		print("⚠ Deck com mudanças não salvas")
		_exibir_mensagem("Suas mudanças não foram salvas.", false)
		# Aqui você poderia adicionar um diálogo de confirmação se desejar
	
	# Volta para o Lobby
	print("→ Voltando para Lobby")
	get_tree().change_scene_to_file(CENA_LOBBY)

func _tem_mudancas_nao_salvas() -> bool:
	"""Verifica se há mudanças não salvas"""
	# Se é novo deck, qualquer coisa é mudança
	if _deck_original.is_empty():
		return not deck_cartas.is_empty()
	
	# Se é edição, compara com original
	var original_nome = _deck_original.get("nome", "")
	if nome_do_deck_atual != original_nome:
		return true
	
	var original_cartas: Array = _deck_original.get("colecao", [])
	return _normalizar_colecao_salva(original_cartas) != _normalizar_deck_atual()

func _normalizar_deck_atual() -> Dictionary:
	var resultado: Dictionary = {}
	for carta in deck_cartas:
		var id := carta.id.strip_edges()
		if id != "":
			resultado[id] = resultado.get(id, 0) + 1
	return resultado

func _normalizar_colecao_salva(colecao: Array) -> Dictionary:
	var resultado: Dictionary = {}
	for entrada in colecao:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var id := str(entrada.get("id", "")).strip_edges()
		var quantidade := int(entrada.get("quantidade", 0))
		if id != "" and quantidade > 0:
			resultado[id] = resultado.get(id, 0) + quantidade
	return resultado

# ============================================================================
# FEEDBACK VISUAL
# ============================================================================
func _exibir_mensagem(texto: String, erro: bool = false) -> void:
	"""Exibe uma mensagem na barra de avisos"""
	if not mensagem_label:
		return
	
	# Mostra a barra de avisos
	var aviso_bar = mensagem_label.get_parent()
	if aviso_bar:
		aviso_bar.visible = true
	
	# Define o texto
	mensagem_label.text = texto
	
	# Define a cor (vermelho para erro, verde para sucesso)
	var cor = Color(1, 0.3, 0.3) if erro else Color(0.3, 1, 0.3)
	mensagem_label.add_theme_color_override("font_color", cor)

# ============================================================================
# VALIDAÇÃO DE REGRAS
# ============================================================================
func verificar_regras_do_deck() -> bool:
	var total_cartas := deck_cartas.size()
	var possui_filhote := false
	var contador_copias : Dictionary = {}
	var copias_ok := true

	for carta in deck_cartas:
		var id: String = carta.id

		var stage_val = carta.get("stage") if carta.get("stage") != null else carta.get("estagio")
		var estagio := str(stage_val if stage_val != null else "").to_lower()

		# Conta as cópias
		contador_copias[id] = contador_copias.get(id, 0) + 1

		# Pergunta para a função oficial qual é o limite
		var limite := _obter_limite_copias(carta)

		if contador_copias[id] > limite:
			copias_ok = false

		if "filhote" in estagio or "bebe" in estagio or "bebê" in estagio:
			possui_filhote = true

	_colorir_regra(rule_text, total_cartas == DeckManager.TAMANHO_DECK_VALIDO)
	_colorir_regra(rule_text2, possui_filhote)

	return (
		total_cartas == DeckManager.TAMANHO_DECK_VALIDO
		and possui_filhote
		and copias_ok
	)
	
func _colorir_regra(label: Label, valida: bool) -> void:
	var cor = Color(0.3, 1.0, 0.3) if valida else Color(1.0, 0.3, 0.3)
	if label:
		label.add_theme_color_override("font_color", cor)


# TODO:
# Mover todas as regras de deck para DeckRules.gd
# (Banlist, Limited List, formatos e validação)

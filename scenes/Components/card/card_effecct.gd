extends Control

# ==============================================================================
# card_effecct.gd — Controlador Visual das Cartas de Efeito (Cataclismo/Vestigio/Territorio)
# Baseado em: res://components/card/card.gd
# Não armazena estado definitivo de jogo. Apenas renderiza dados recebidos.
# ==============================================================================

signal hovered(recurso_carta)
signal clicado(nodo_carta, botao)

enum Modo { COMPLETO, MINI }

@export var modo: Modo = Modo.COMPLETO
@export var virada_para_baixo: bool = false


# Cartas de Efeito (Cataclismo/Vestígio/Território) são EffectResource,
# não CardResource — CardResource hoje é exclusivo de Animal.
var recurso_carta: EffectResource = null

# Dicionário para armazenar referências aos labels (mais seguro)
var labels: Dictionary = {}
var sprites: Dictionary = {}
var card_image: TextureRect = null

# Container para a imagem/arte da carta
var image_container: PanelContainer = null

# ----------------------------------------------------------------------------
# CICLO DE VIDA E INTERAÇÃO
# ----------------------------------------------------------------------------
func _ready() -> void:
	"""Inicializa o script e carrega as referências dos nós"""
	_carregar_referencias()
	
	# Conecta sinal de mouse entered
	mouse_entered.connect(_on_mouse_entered)
	gui_input.connect(_on_gui_input)
	
	# Atualiza o modo de exibição
	_atualizar_modo_exibicao()


func _carregar_referencias() -> void:
	"""Carrega referências dos nós de forma segura"""
	# O nó raiz espera encontrar uma TextureRect chamada "moldura" 
	# que contém a imagem de fundo da carta (CardImage)
	card_image = get_node_or_null("moldura")
	
	if card_image == null:
		push_error("Erro crítico: moldura (CardImage) não encontrado em CardEffect.tscn")
		return
	
	# Container para a arte/imagem da carta
	image_container = get_node_or_null("VBoxContainer/art/animailimagem")
	if image_container == null:
		push_warning("Container de imagem (PanelContainer) não encontrado")
	
	# Lista de labels esperados (específicos para cartas de efeito)
	var label_names = [
		"nome",      # Nome da carta de efeito
		"efeito"     # Descrição do efeito
	]
	
	# Carrega labels de forma segura
	for label_name in label_names:
		var node = get_node_or_null("VBoxContainer/header/" + label_name) if label_name == "nome" else get_node_or_null("VBoxContainer/info/MarginContainer/VBoxContainer/" + label_name)
		
		if node:
			labels[label_name] = node
			print("✓ Label '%s' carregado com sucesso" % label_name)
		else:
			push_warning("Label não encontrado: %s" % label_name)


func _on_mouse_entered() -> void:
	"""Emite sinal quando mouse entra na área da carta"""
	if recurso_carta:
		hovered.emit(recurso_carta)

# ----------------------------------------------------------------------------
# INTERFACE PÚBLICA DE CARREGAMENTO
# ----------------------------------------------------------------------------
func inicializar(recurso: EffectResource) -> void:
	"""Inicializa a carta com um recurso CardResource"""
	if recurso == null:
		push_error("Erro: Tentou inicializar uma carta visual com um Resource nulo.")
		return
		
	recurso_carta = recurso
	
	if virada_para_baixo:
		_renderizar_verso()
	else:
		_renderizar_frente()


func definir_face(para_baixo: bool) -> void:
	"""Define se a carta está virada para cima ou para baixo"""
	if virada_para_baixo == para_baixo:
		return
	virada_para_baixo = para_baixo
	if recurso_carta:
		if virada_para_baixo: 
			_renderizar_verso() 
		else: 
			_renderizar_frente()

# ----------------------------------------------------------------------------
# MÉTODOS INTERNOS DE RENDERIZAÇÃO
# ----------------------------------------------------------------------------
func _renderizar_verso() -> void:
	"""Renderiza o verso da carta"""
	HelperUI.aplicar_verso(card_image, card_image.get_children() if card_image else [])


func _renderizar_frente() -> void:
	"""Renderiza a frente da carta com todos os elementos"""
	if recurso_carta == null:
		push_error("Erro: Recurso da carta é nulo em _renderizar_frente()")
		return
	
	# Exibe todos os elementos
	_exibir_todos_os_elementos()
	
	# Aplica a textura de fundo baseada no tipo de efeito
	_aplicar_textura_de_fundo()
	
	# Aplica os dados do recurso aos labels
	_set_label_text("nome", recurso_carta.name)
	_set_label_text("efeito", recurso_carta.text_ui)
	
	# Aplica a cor do texto baseada no tipo
	_aplicar_cor_texto()


func _aplicar_textura_de_fundo() -> void:
	"""Aplica a textura de fundo baseada no super_type da carta"""
	if card_image == null or recurso_carta == null:
		return
	
	var super_type = recurso_carta.super_type.to_lower().strip_edges()
	var caminho_textura := "res://Assets/Cards/Vestigios/TCG Card Vestigio.png"

	# Seleciona a textura baseada no tipo de efeito
	match super_type:
		"cataclismo":
			caminho_textura = "res://Assets/Cards/Cataclismos/TCG Card Cataclismo.png"
		"vestigio":
			caminho_textura = "res://Assets/Cards/Vestigios/TCG Card Vestigio.png"
		_:
			push_warning("Tipo de efeito desconhecido: %s. Usando padrão (Vestigio)" % super_type)
	
	# Carrega a textura se existir
	if ResourceLoader.exists(caminho_textura):
		card_image.texture = load(caminho_textura)
	else:
		push_error("Erro: O arquivo de textura não foi encontrado em: " + caminho_textura)


func _aplicar_cor_texto() -> void:
	"""Aplica cores de texto baseadas no tipo de carta"""
	if recurso_carta == null:
		return
	
	# ========================================================================
	# 1. PARTE DO EFEITO (Mantida exatamente como você fez e que já funcionava)
	# ========================================================================
	var tem_efeito := false
	var label_efeito: Label = null
	
	if "efeito" in labels:
		label_efeito = labels["efeito"] as Label
		if label_efeito != null:
			tem_efeito = true
		else:
			push_warning("Label 'efeito' não é válido ou é nulo")
	else:
		push_warning("Label 'efeito' não está no dicionário de labels")
	
	# ========================================================================
	# 2. PARTE DO NOME (Nova checagem independente para não quebrar o efeito)
	# ========================================================================
	var tem_nome := false
	var label_nome: Label = null
	
	if "nome" in labels:
		label_nome = labels["nome"] as Label
		if label_nome != null:
			tem_nome = true
		else:
			push_warning("Label 'nome' não é válido ou é nulo")
	else:
		push_warning("Label 'nome' não está no dicionário de labels")
	
	# ========================================================================
	# 3. APLICAÇÃO DAS CORES (Aplica em quem estiver disponível)
	# ========================================================================
	var super_type = recurso_carta.super_type.to_lower().strip_edges()
	
	match super_type:
		"cataclismo":
			if tem_efeito: label_efeito.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))  # Branco
			if tem_nome: label_nome.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))     # Branco
		"vestigio":
			if tem_efeito: label_efeito.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0)) # Preto
			if tem_nome: label_nome.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0))# Preto
		_:
			if tem_efeito: label_efeito.modulate = Color.BLACK          # Padrão
			if tem_nome: label_nome.modulate = Color.BLACK              # Padrão
			
func _exibir_todos_os_elementos() -> void:
	"""Exibe todos os elementos da carta"""
	if card_image:
		for filho in card_image.get_children():
			if filho is Control:
				filho.show()


func _atualizar_modo_exibicao() -> void:
	"""Atualiza o tamanho e visibilidade baseado no modo"""
	if modo == Modo.MINI:
		custom_minimum_size = Vector2(100, 40)
		size = custom_minimum_size
		if card_image: 
			card_image.hide()
	else:
		custom_minimum_size = Vector2(150, 233)
		size = custom_minimum_size
		if card_image: 
			card_image.show()

# ============================================================================
# HELPER FUNCTIONS — Métodos Seguros para Acessar Elementos
# ============================================================================

func _set_label_text(label_name: String, text: String) -> void:
	"""Define texto de um label de forma segura"""
	if label_name not in labels:
		push_warning("Label '%s' não foi encontrado no dicionário de labels" % label_name)
		return
	
	var label = labels[label_name] as Label
	if label:
		label.text = text
	else:
		push_warning("Label '%s' não é uma referência válida" % label_name)


func _get_label_text(label_name: String) -> String:
	"""Obtém texto de um label de forma segura"""
	if label_name not in labels:
		return ""
	
	var label = labels[label_name] as Label
	if label:
		return label.text
	return ""


func set_image(texture: Texture2D) -> void:
	"""Define a imagem/arte da carta no container"""
	if image_container == null:
		push_warning("Container de imagem não está disponível")
		return
	
	# Limpa o container anterior
	for child in image_container.get_children():
		child.queue_free()
	
	# Cria e adiciona uma nova TextureRect
	var texture_rect = TextureRect.new()
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	
	image_container.add_child(texture_rect)
	
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			clicado.emit(self, event.button_index)

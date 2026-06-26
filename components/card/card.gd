extends Control

# ==============================================================================
# card.gd — Controlador Visual da Carta (components/card/card.gd)
# Não armazena estado definitivo de jogo. Apenas renderiza dados recebidos.
# ==============================================================================

signal hovered(recurso_carta)
signal clicado(nodo_carta, botao)

enum Modo { COMPLETO, MINI }

@export var modo: Modo = Modo.COMPLETO
@export var virada_para_baixo: bool = false

const TEXTURA_VERSO := "res://assest/textures/cards/verso_nome.jpg"

# Agora retemos o Objeto Resource nativo e tipado em vez de um dicionário solto
var recurso_carta: CardResource = null

# Dicionário para armazenar referências aos labels (mais seguro)
var labels: Dictionary = {}
var sprites: Dictionary = {}
var card_image: TextureRect = null

# ----------------------------------------------------------------------------
# CICLO DE VIDA E INTERAÇÃO
# ----------------------------------------------------------------------------
func _ready() -> void:
	# Tenta carregar as referências de forma segura
	_carregar_referencias()
	
	mouse_entered.connect(_on_mouse_entered)
	gui_input.connect(_on_gui_input)
	_atualizar_modo_exibicao()


func _carregar_referencias() -> void:
	"""Carrega referências dos nós de forma segura"""
	card_image = get_node_or_null("CardImage")
	
	if card_image == null:
		push_error("Erro crítico: CardImage não encontrado em Card.tscn")
		return
	
	# Lista de labels esperados
	var label_names = [
		"animal", "estagio", "hp", "comida", "habilidade", 
		"habilidade2", "ataque", "custo", "dano", "efeito", "recuo"
	]
	
	# Carrega labels de forma segura
	for label_name in label_names:
		var node = card_image.get_node_or_null(label_name)
		if node:
			labels[label_name] = node
		else:
			push_warning("Label não encontrado: %s" % label_name)
	
	# Carrega sprites de forma segura
	var sprite_names = ["dietaicon1", "dietaicon3"]
	for sprite_name in sprite_names:
		var node = card_image.get_node_or_null(sprite_name)
		if node:
			sprites[sprite_name] = node
		else:
			push_warning("Sprite não encontrado: %s" % sprite_name)

func _on_mouse_entered() -> void:
	if recurso_carta:
		hovered.emit(recurso_carta)

# ----------------------------------------------------------------------------
# INTERFACE PÚBLICA DE CARREGAMENTO
# ----------------------------------------------------------------------------
# Agora a sua cena recebe diretamente o arquivo .tres da carta!
func inicializar(recurso: CardResource) -> void:
	if recurso == null:
		push_error("Erro: Tentou inicializar uma carta visual com um Resource nulo.")
		return
		
	recurso_carta = recurso
	
	if virada_para_baixo:
		_renderizar_verso()
	else:
		_renderizar_frente()


func definir_face(para_baixo: bool) -> void:
	if virada_para_baixo == para_baixo:
		return
	virada_para_baixo = para_baixo
	if recurso_carta:
		if virada_para_baixo: _renderizar_verso() 
		else: _renderizar_frente()

# ----------------------------------------------------------------------------
# MÉTODOS INTERNOS DE RENDERIZAÇÃO
# ----------------------------------------------------------------------------
func _renderizar_frente() -> void:
	if recurso_carta == null: return
	
	_exibir_todos_os_elementos()
	_aplicar_textura_de_fundo()
	
	# --- 1. Dados Universais (Comuns a todas as cartas) ---
	_set_label_text("animal", recurso_carta.name)
	_set_label_text("efeito", recurso_carta.text_ui)
	
	# Limpa labels específicos por segurança antes de aplicar regras de categoria
	_set_label_text("estagio", "")
	_set_label_text("hp", "")
	_set_label_text("comida", "")
	_set_label_text("habilidade", "")
	_set_label_text("habilidade2", "")
	_set_label_text("ataque", "")
	_set_label_text("custo", "")
	_set_label_text("dano", "")
	_set_label_text("recuo", "")
	
	_hide_sprite("dietaicon1")
	_hide_sprite("dietaicon3")

	# --- 2. Renderização Exclusiva de Animais ---
	if recurso_carta.super_type == "animal":
		var estagio_texto: String = str(recurso_carta.stage).strip_edges()
		if not estagio_texto.is_empty():
			_set_label_text("estagio", estagio_texto[0].to_upper())
		else:
			_set_label_text("estagio", "")
		
		_set_label_text("hp", str(recurso_carta.hp))
		_set_label_text("comida", str(recurso_carta.food_points))
		
		# Habilidade do Dinossauro (se houver)
		if recurso_carta.ability_name != "":
			_set_label_text("habilidade", recurso_carta.ability_name)
			# Tenta carregar a descrição diretamente do banco de habilidades nativo que criamos!
			var safe_ability_name = recurso_carta.ability_name.validate_filename()
			var ability_path = "res://data/abilities/" + recurso_carta.id + "_" + safe_ability_name + ".tres"
			
			# Se achar o recurso da habilidade, lê o texto descritivo profissional dela
			if ResourceLoader.exists(ability_path):
				var ab_res = load(ability_path) as AbilityResource
				if ab_res: 
					_set_label_text("habilidade2", ab_res.text_ui)
			else:
				# Fallback de segurança
				_set_label_text("habilidade2", "")
		
		# Ataque e Custos
		_set_label_text("ataque", recurso_carta.attack_name)
		_set_label_text("custo", recurso_carta.attack_cost)
		
		if recurso_carta.damage_base > 0:
			_set_label_text("dano", str(recurso_carta.damage_base))
		else:
			_set_label_text("dano", "")
			
		if recurso_carta.cost_retreat > 0:
			_set_label_text("recuo", "Recuar: " + str(recurso_carta.cost_retreat))
		else:
			_set_label_text("recuo", "Recuo livre")
			
		# Renderização dos Ícones de Dieta (Alimentação) baseada no sub_type do recurso
		
		var texto_dieta = recurso_carta.sub_type.to_lower()
				
		# Limpa colchetes e espaços caso venha no formato "[Carnivoro, Psivoro]"
		texto_dieta = texto_dieta.replace("[", "").replace("]", "")
		
		# Divide as dietas por vírgula em uma lista
		var lista_dietas: Array = []
		for item in texto_dieta.split(","):
			var termo = item.strip_edges()
			if termo != "":
				lista_dietas.append(termo)
		
		# Se for o termo único "onivoro", transformamos nos dois ícones padrão
		if lista_dietas.size() == 1 and lista_dietas[0] == "onivoro":
			lista_dietas = ["carnivoro", "herbivoro"]
		
		# Verifica a quantidade de dietas válidas encontradas para distribuir nos sprites
		if lista_dietas.size() == 1:
			var textura = _obter_textura_icone_dieta(lista_dietas[0])
			if textura:
				_show_sprite("dietaicon1")
				
				# Acessa o sprite direto pelo seu dicionário de referências
				if sprites.has("dietaicon1") and sprites["dietaicon1"] != null:
					sprites["dietaicon1"].texture = textura
				
		elif lista_dietas.size() >= 2:
			var textura1 = _obter_textura_icone_dieta(lista_dietas[0])
			var textura2 = _obter_textura_icone_dieta(lista_dietas[1])
			
			if textura1:
				_show_sprite("dietaicon1")
				if sprites.has("dietaicon1") and sprites["dietaicon1"] != null:
					sprites["dietaicon1"].texture = textura1
					
			if textura2:
				_show_sprite("dietaicon3")
				if sprites.has("dietaicon3") and sprites["dietaicon3"] != null:
					sprites["dietaicon3"].texture = textura2
	# --- 3. Renderização de Outras Categorias (Cataclismo, Vestígio, etc) ---
	else:
		# Em cartas de efeito, o super_type (Categoria) vai para o lugar do estágio
		_set_label_text("estagio", recurso_carta.super_type.capitalize())
func _obter_textura_icone_dieta(tipo_dieta: String) -> Texture2D:
	match tipo_dieta:
		"carnivoro":
			return load("res://assest/textures/cards/icone carnivoro.png") # <- Adicione aqui o caminho do ícone
		"herbivoro":
			return load("res://assest/textures/cards/icone herbivoro.png") # <- Adicione aqui o caminho do ícone
		"psivoro":
			return load("res://assest/textures/cards/icone psivoro.png")   # <- Adicione aqui o caminho do ícone
		_:
			return null

func _aplicar_textura_de_fundo() -> void:
	if card_image == null or recurso_carta == null: return
	
	var cor = recurso_carta.color.to_lower().strip_edges()
	var caminho_textura := "res://assest/textures/cards/Frente base blue.png"

	match cor:
		"azul":     caminho_textura = "res://assest/textures/cards/TCG Card azul.png"
		"vermelho": caminho_textura = "res://assest/textures/cards/TCG Card vermelho.png"
		"verde":    caminho_textura = "res://assest/textures/cards/TCG Card verde.png"
		"amarelo":  caminho_textura = "res://assest/textures/cards/TCG Card amarelo.png"
		"marrom":   caminho_textura = "res://assest/textures/cards/TCG Card marrom.png"

	if ResourceLoader.exists(caminho_textura):
		card_image.texture = load(caminho_textura)


func _renderizar_verso() -> void:
	if card_image and ResourceLoader.exists(TEXTURA_VERSO):
		card_image.texture = load(TEXTURA_VERSO)
		for filho in card_image.get_children():
			if filho is Control:
				filho.hide()
		_hide_sprite("dietaicon1")
		_hide_sprite("dietaicon3")


func _exibir_todos_os_elementos() -> void:
	if card_image:
		for filho in card_image.get_children():
			if filho is Control:
				filho.show()


func _atualizar_modo_exibicao() -> void:
	if modo == Modo.MINI:
		custom_minimum_size = Vector2(100, 40)
		size = custom_minimum_size
		if card_image: card_image.hide()
	else:
		custom_minimum_size = Vector2(150, 233)
		size = custom_minimum_size
		if card_image: card_image.show()


# ============================================================================
# HELPER FUNCTIONS — Métodos Seguros para Acessar Elementos
# ============================================================================

func _set_label_text(label_name: String, text: String) -> void:
	"""Define texto de um label de forma segura"""
	if label_name in labels:
		var label = labels[label_name] as Label
		if label:
			label.text = text
	# Se o label não existir, apenas ignora (sem erro)


func _show_sprite(sprite_name: String) -> void:
	"""Mostra um sprite de forma segura"""
	if sprite_name in sprites:
		var sprite = sprites[sprite_name] as Node
		if sprite:
			sprite.show()


func _hide_sprite(sprite_name: String) -> void:
	"""Esconde um sprite de forma segura"""
	if sprite_name in sprites:
		var sprite = sprites[sprite_name] as Node
		if sprite:
			sprite.hide()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			clicado.emit(self, event.button_index)

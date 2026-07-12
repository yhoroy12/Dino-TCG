extends Control

# ==============================================================================
# CardTerritorio.gd — Controlador Visual de Campos/Biomas (Território)
# ==============================================================================

signal hovered(recurso_carta: EffectResource)
signal clicado(nodo_carta: Control, botao: int)
signal removido(nodo_carta: Control)

# Território é EffectResource, não CardResource — CardResource hoje
# é exclusivo de Animal.
var recurso_carta: EffectResource = null

@onready var borda: TextureRect       = $borda
@onready var label_nome: Label        = $nome
@onready var label_efeito: Label      = $efeito
@onready var placeholder: TextureRect = $placeholder

@export var virada_para_baixo: bool = false

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	gui_input.connect(_on_gui_input)


func _on_mouse_entered() -> void:
	if recurso_carta:
		hovered.emit(recurso_carta)


# Implementação do método padrão unificado do projeto
func inicializar(recurso: EffectResource) -> void:
	if recurso == null:
		push_error("Erro: Tentou inicializar CardTerritorio com Resource nulo.")
		return
		
	recurso_carta = recurso
	
	if virada_para_baixo:
		_renderizar_verso()
	else:
		_renderizar_frente()
		
		
func _renderizar_frente ():
	# 1. Preenche os campos textuais estáticos e básicos
	if label_nome:   
		label_nome.text = recurso_carta.name
		
	if label_efeito: 
		label_efeito.text = recurso_carta.text_ui
	
	# 2. SISTEMA DE BORDA TEMÁTICA POR NOME DO TERRITÓRIO
	var nome_limpo = recurso_carta.name.to_lower().strip_edges()
	var caminho_borda = "res://Assets/Cards/Territories/TCG Card Territorio " + nome_limpo + ".png"
		
	# Fallback inteligente: se não existir uma textura específica com o nome exato da carta,
	# você pode usar uma genérica padrão para evitar caminhos quebrados
	if ResourceLoader.exists(caminho_borda) and borda:
		borda.texture = load(caminho_borda)
	elif borda:
		# Fallback para o território padrão existente se a arte gerada por IA não estiver no projeto
		borda.texture = preload("res://Assets/Cards/Territories/TCG Card Territorio Fartura e Pobreza.png")
	
	# 3. Carregamento dinâmico da arte central pelo ID da carta
	if placeholder:
		var caminho_arte = "res://Assets/Arts/Territories/" + recurso_carta.id + ".png"
		if ResourceLoader.exists(caminho_arte):
			placeholder.texture = load(caminho_arte)
		else:
			placeholder.texture = preload("res://Assets/placeholder.png")

func definir_face(para_baixo: bool) -> void:
	if virada_para_baixo == para_baixo:
		return
	virada_para_baixo = para_baixo
	if recurso_carta:
		if virada_para_baixo: _renderizar_verso()
		else: _renderizar_frente()


func _renderizar_verso() -> void:
	HelperUI.aplicar_verso(borda, [label_nome, label_efeito, placeholder])

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			clicado.emit(self, event.button_index)

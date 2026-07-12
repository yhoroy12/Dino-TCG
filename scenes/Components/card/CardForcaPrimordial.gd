extends Control

# ==============================================================================
# CardForcaPrimordial.gd — Controlador Visual de Energias (Força Primordial)
# ==============================================================================

signal hovered(recurso_carta: EffectResource)
signal clicado(nodo_carta: Control, botao: int)
signal removido(nodo_carta: Control)

# Energia (Força Primordial) é EffectResource, não CardResource —
# CardResource hoje é exclusivo de Animal.
var recurso_carta: EffectResource = null

@onready var borda: TextureRect             = $borda
@onready var label_nome: Label              = $Nome
@onready var label_efeito: Label            = $efeito
@onready var placeholder_img: TextureRect   = $placeholderimagem

@export var virada_para_baixo: bool = false

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	gui_input.connect(_on_gui_input)


func _on_mouse_entered() -> void:
	if recurso_carta:
		hovered.emit(recurso_carta)


# Transição para o método padrão unificado do projeto
func inicializar(recurso: EffectResource) -> void:
	if recurso == null:
		push_error("Erro: Tentou inicializar CardForcaPrimordial com Resource nulo.")
		return
		
	recurso_carta = recurso
	
	if virada_para_baixo:
		_renderizar_verso()
	else:
		_renderizar_frente()

func _renderizar_frente():	
	# 1. Preenche os textos básicos baseados nas propriedades diretas
	if label_nome:   
		label_nome.text = "Força Primordial"
		
	if label_efeito: 
		label_efeito.text = recurso_carta.text_ui
	
	# 2. SISTEMA DE COR DINÂMICA DA BORDA
	var cor_carta = recurso_carta.mec_filter_color.to_lower().strip_edges()
	
	# Monta o caminho dinâmico exatamente como o teu projeto estruturado precisa
	var caminho_borda = "res://Assets/Cards/Energies/TCG Card Primordial " + cor_carta + ".png"
	
	# Verifica se o arquivo de textura existe antes de tentar carregar
	if ResourceLoader.exists(caminho_borda) and borda:
		borda.texture = load(caminho_borda)
	else:
		push_warning("CardForcaPrimordial: Textura não encontrada em: " + caminho_borda)
		
	# Opcional: Se decidires colocar imagens únicas para cada energia pelo ID no futuro
	if placeholder_img:
		var caminho_arte = "res://Assets/Arts/Energies/" + recurso_carta.id + ".png"
		if ResourceLoader.exists(caminho_arte):
			placeholder_img.texture = load(caminho_arte)
		else:
			placeholder_img.texture = preload("res://Assets/placeholder.png")

func _renderizar_verso() -> void:
	HelperUI.aplicar_verso(borda, [label_nome, label_efeito, placeholder_img])

func definir_face(para_baixo: bool) -> void:
	if virada_para_baixo == para_baixo:
		return
	virada_para_baixo = para_baixo
	if recurso_carta:
		if virada_para_baixo: _renderizar_verso()
		else: _renderizar_frente()
		

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			clicado.emit(self, event.button_index)

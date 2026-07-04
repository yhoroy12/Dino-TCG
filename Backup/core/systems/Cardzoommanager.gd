extends Control

# ==============================================================================
# CardZoomManager — Gerenciador de Zoom e Exibição de Cartas
# Gerencia a ampliação e redução de cartas quando o mouse passa por cima delas
# ==============================================================================

signal carta_zoom_iniciado(carta_resource: CardResource)
signal carta_zoom_finalizado()

# ============================================================================
# EXPORTVARS - Parâmetros ajustáveis
# ============================================================================

@export var escala_zoom: float = 1.5  # 150% do tamanho original
@export var tempo_transicao: float = 0.2  # Tempo de animação em segundos
@export var usar_easing: bool = true  # Usar easing suave
@export var tipo_easing: Tween.EaseType = Tween.EASE_OUT  # Tipo de easing
@export var transicao_tipo: Tween.TransitionType = Tween.TRANS_QUAD  # Tipo de transição

# ============================================================================
# VARIÁVEIS INTERNAS
# ============================================================================

var escala_original: Vector2 = Vector2.ONE
var posicao_original: Vector2 = Vector2.ZERO
var carta_zoom_atual: Control = null
var tween_ativo: Tween = null

# Referências dos nós
var card_holder: Control = null
var zoom_panel: Control = null

# ============================================================================
# CICLO DE VIDA
# ============================================================================

func _ready() -> void:
	"""Inicializa o gerenciador de zoom"""
	print("✓ CardZoomManager inicializado")
	_validar_referencias()


func _validar_referencias() -> void:
	"""Valida se todas as referências necessárias existem"""
	card_holder = get_node_or_null(".")  # Assume que este é o container
	
	if card_holder == null:
		push_error("Erro: CardZoomManager não encontrou referência ao nó raiz")
		return
	
	print("✓ CardZoomManager: Referências validadas")


# ============================================================================
# INTERFACE PÚBLICA - FUNÇÕES PARA USAR EM OUTROS SCRIPTS
# ============================================================================

func exibir_zoom_carta(carta_visual: Control, recurso_carta: CardResource) -> void:
	"""
	Exibe a carta com zoom.
	
	Parâmetros:
	- carta_visual: Nó Control da carta visual (child de algum container)
	- recurso_carta: CardResource com os dados da carta
	"""
	if carta_visual == null:
		push_error("Erro: carta_visual é nulo")
		return
	
	if recurso_carta == null:
		push_error("Erro: recurso_carta é nulo")
		return
	
	# Se houver uma carta em zoom, cancela ela primeiro
	if carta_zoom_atual != null:
		esconder_zoom_carta()
	
	# Define a nova carta em zoom
	carta_zoom_atual = carta_visual
	escala_original = carta_visual.scale
	posicao_original = carta_visual.global_position
	
	# Emite sinal
	carta_zoom_iniciado.emit(recurso_carta)
	
	# Aplica a animação de zoom
	_animar_zoom_in(carta_visual)
	
	print("🔍 Zoom iniciado: %s" % recurso_carta.name)


func esconder_zoom_carta() -> void:
	"""Desfaz o zoom da carta atual"""
	if carta_zoom_atual == null:
		return
	
	# Cancela tween anterior se existir
	if tween_ativo:
		tween_ativo.kill()
		tween_ativo = null
	
	# Aplica a animação de zoom out
	_animar_zoom_out(carta_zoom_atual)
	
	print("🔙 Zoom finalizado")
	carta_zoom_finalizado.emit()


func obter_carta_em_zoom() -> Control:
	"""Retorna a carta que está em zoom (ou null)"""
	return carta_zoom_atual


# ============================================================================
# MÉTODOS DE ANIMAÇÃO INTERNOS
# ============================================================================

func _animar_zoom_in(carta: Control) -> void:
	"""Anima o zoom in da carta"""
	if carta == null:
		return
	
	# Cancela tween anterior se existir
	if tween_ativo:
		tween_ativo.kill()
	
	# Cria nova tween
	tween_ativo = create_tween()
	
	# Configura a tween
	if usar_easing:
		tween_ativo.set_ease(tipo_easing)
		tween_ativo.set_trans(transicao_tipo)
	
	tween_ativo.set_duration(tempo_transicao)
	
	# Anima escala
	tween_ativo.tween_property(
		carta,
		"scale",
		Vector2(escala_zoom, escala_zoom),
		tempo_transicao
	)
	
	print("📈 Animação de zoom in iniciada: escala = %.2fx" % escala_zoom)


func _animar_zoom_out(carta: Control) -> void:
	"""Anima o zoom out da carta (volta ao tamanho original)"""
	if carta == null:
		return
	
	# Cancela tween anterior se existir
	if tween_ativo:
		tween_ativo.kill()
	
	# Cria nova tween
	tween_ativo = create_tween()
	
	# Configura a tween
	if usar_easing:
		tween_ativo.set_ease(tipo_easing)
		tween_ativo.set_trans(transicao_tipo)
	
	tween_ativo.set_duration(tempo_transicao)
	
	# Anima escala de volta
	tween_ativo.tween_property(
		carta,
		"scale",
		escala_original,
		tempo_transicao
	)
	
	# Quando termina, limpa a referência
	tween_ativo.tween_callback(func():
		if carta == carta_zoom_atual:
			carta_zoom_atual = null
	)
	
	print("📉 Animação de zoom out iniciada")


# ============================================================================
# HELPERS DE DEBUG
# ============================================================================

func debug_listar_infos() -> void:
	"""Lista informações de debug"""
	print("\n=== CardZoomManager Debug Info ===")
	print("Escala de Zoom: %.2f" % escala_zoom)
	print("Tempo de Transição: %.2fs" % tempo_transicao)
	print("Usar Easing: %s" % ("Sim" if usar_easing else "Não"))
	print("Carta em Zoom Atual: %s" % ("Sim" if carta_zoom_atual != null else "Não"))
	print("Tween Ativa: %s" % ("Sim" if tween_ativo != null else "Não"))
	print("====================================\n")

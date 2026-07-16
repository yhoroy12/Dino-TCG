extends Control
class_name CardPreviewPanel

# ==============================================================================
# CardPreviewPanel — Componente Isolado de Zoom/Preview de Cartas
# Exibe uma cópia ampliada e legível de QUALQUER carta do jogo de forma genérica.
# Reutilizável em: Mesa do Jogo, Deck Builder, Coleção, etc.
# ==============================================================================

# Parâmetros visuais ajustáveis
@export var tempo_transicao: float = 0.15
@export var tipo_easing: Tween.EaseType = Tween.EASE_OUT
@export var transicao_tipo: Tween.TransitionType = Tween.TRANS_QUAD

# Variáveis internas de controle
var recurso_atual: CardBaseResource = null
var tween_ativo: Tween = null

func _ready() -> void:
	# Garante que o painel de preview limpa resíduos visuais do editor ao iniciar
	_limpar_painel_imediato()
	print("✓ CardPreviewPanel inicializado e pronto para uso.")


## Interface Pública: Exibe a versão ampliada de qualquer CardBaseResource
func exibir_preview(recurso_carta: CardBaseResource, virada_para_baixo: bool = false) -> void:
	if recurso_carta == null:
		esconder_preview()
		return
		
	# Se já estiver exibindo EXATAMENTE a mesma carta na mesma orientação, ignora o retrabalho
	if recurso_atual == recurso_carta:
		return
		
	recurso_atual = recurso_carta
	_limpar_painel_imediato()
	
	# Se a carta estiver de costas, renderiza o verso padrão respeitando o tamanho deste container
	if virada_para_baixo:
		var verso = HelperUI.criar_verso_generico(size)
		if verso:
			verso.modulate.a = 0.0
			add_child(verso)
			_executar_fade_in(verso)
		return

	# Instancia dinamicamente a cena física correta via HelperUI usando os limites deste painel
	var dados_instancia = HelperUI.instanciar_carta_escalada(recurso_carta, size, false)
	var envelope = dados_instancia.get("envelope")
	
	if envelope == null:
		push_error("CardPreviewPanel: Falha ao gerar envelope da carta no HelperUI.")
		return
		
	# Prepara o nó com opacidade zerada para a transição suave
	envelope.modulate.a = 0.0
	add_child(envelope)
	
	_executar_fade_in(envelope)


## Interface Pública: Limpa a exibição com um efeito suave de Fade-out
func esconder_preview() -> void:
	if recurso_atual == null:
		return
		
	recurso_atual = null
	
	if tween_ativo:
		tween_ativo.kill()
		
	if get_child_count() == 0:
		return
		
	var nó_atual = get_child(0)
	
	tween_ativo = create_tween().set_ease(tipo_easing).set_trans(transicao_tipo)
	tween_ativo.tween_property(nó_atual, "modulate:a", 0.0, tempo_transicao)
	tween_ativo.tween_callback(func():
		if get_child_count() > 0:
			get_child(0).queue_free()
	)


# ==============================================================================
# MÉTODOS INTERNOS / AUXILIARES
# ==============================================================================

func _executar_fade_in(alvo: Control) -> void:
	if tween_ativo:
		tween_ativo.kill()
		
	tween_ativo = create_tween().set_ease(tipo_easing).set_trans(transicao_tipo)
	tween_ativo.tween_property(alvo, "modulate:a", 1.0, tempo_transicao)


func _limpar_painel_imediato() -> void:
	if tween_ativo:
		tween_ativo.kill()
	for filho in get_children():
		filho.queue_free()

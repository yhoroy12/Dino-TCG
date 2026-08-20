class_name AIAgent
extends PlayerAgent

var _arvore: SceneTree
var tempo_entre_acoes: float = 1.0

func _init(p_jogador_id: int, p_arvore: SceneTree, p_tempo_entre_acoes: float = 1.0) -> void:
	super._init(p_jogador_id)
	_arvore = p_arvore
	tempo_entre_acoes = p_tempo_entre_acoes

func decidir_promocao_ativo(banco_disponivel: Array) -> AnimalInstance:
	if banco_disponivel.is_empty():
		print("🤖 IA: Sem banco disponível para promoção.")
		return null

	await _arvore.create_timer(tempo_entre_acoes).timeout

	var substituto: AnimalInstance = banco_disponivel[0]
	print("🤖 IA: Escolheu promover '%s' para a posição ativa." % substituto.card.name)
	return substituto
func decidir_selecao_cartas(elegiveis: Array, quantidade: int, contexto: String) -> Array:
	if elegiveis.is_empty():
		return []

	await _arvore.create_timer(tempo_entre_acoes).timeout

	# Heurística simples por enquanto: pega as N primeiras elegíveis.
	# Vale evoluir quando a IA precisar decidir com mais critério
	# (ex: preferir a cor de energia que falta no ativo).
	var quantidade_real: int = mini(quantidade, elegiveis.size())
	var escolha: Array = elegiveis.slice(0, quantidade_real)
	print("🤖 IA: Selecionou %d carta(s) [contexto: %s]." % [escolha.size(), contexto])
	return escolha

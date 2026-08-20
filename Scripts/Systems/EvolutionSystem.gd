class_name EvolutionSystem

# ==================================================
# EVOLUTION SYSTEM (Estático Puro)
# Valida e executa a evolução. Não emite sinais.
# ==================================================

static func pode_crescer(
	instancia: AnimalInstance,
	carta_evolucao: CardResource,
	permite_no_turno_inicial: bool = false
) -> bool:

	if instancia == null or carta_evolucao == null:
		return false

	if instancia.entrou_este_turno or instancia.evoluiu_este_turno:
		return false

	if carta_evolucao.grow_from != instancia.card.id:
		return false

	if GameState.turno_atual <= 1 and not permite_no_turno_inicial:
		return false

	if not FoodSystem.pode_pagar_crescimento(instancia):
		return false

	return true


static func crescer(
	instancia: AnimalInstance,
	carta_evolucao: CardResource,
	permite_no_turno_inicial: bool = false
) -> bool:

	if not pode_crescer(instancia, carta_evolucao, permite_no_turno_inicial):
		return false

	var carta_antiga: CardResource = instancia.card

	# 1. Desconta APENAS o custo de crescimento da comida acumulada (preserva o resto)
	FoodSystem.consumir_para_crescimento(instancia)

	# 2. Empilha a carta antiga no histórico de evolução
	instancia.pilha_evolucao.append(carta_antiga)
	instancia.card = carta_evolucao

	# 3. HP: Preserva o dano sofrido em pontos absolutos
	var dano_acumulado: int = carta_antiga.hp - instancia.current_hp
	instancia.current_hp = max(1, carta_evolucao.hp - dano_acumulado)

	# 4. Limpa condições de status temporárias
	ConditionSystem.limpar_todas_as_condicoes(instancia)

	instancia.evoluiu_este_turno = true

	return true

class_name EvolutionSystem

# ==================================================
# EVOLUTION SYSTEM
# Responsável por:
# - Verificar evolução
# - Executar evolução
# ==================================================


static func pode_evoluir(
	instancia : AnimalInstance,
	carta_evolucao : CardResource
) -> bool:

	if instancia == null:
		return false

	if carta_evolucao == null:
		return false

	# Não pode evoluir no turno em que entrou
	if instancia.entrou_este_turno:
		return false

	# Não pode evoluir duas vezes no mesmo turno
	if instancia.evoluiu_este_turno:
		return false

	# Verifica se a evolução corresponde
	if carta_evolucao.stage_from != instancia.card.card_id:
		return false

	return true


static func evoluir(
	instancia : AnimalInstance,
	carta_evolucao : CardResource
) -> bool:

	if !pode_evoluir(instancia, carta_evolucao):
		return false

	var carta_antiga = instancia.card
	var hp_atual = instancia.current_hp

	instancia.card = carta_evolucao

	var dano_sofrido = carta_antiga.hp - hp_atual

	instancia.current_hp = max(
		1,
		carta_evolucao.hp - dano_sofrido
	)

	instancia.evoluiu_este_turno = true

	return true

	if !pode_evoluir(instancia, carta_evolucao):
		return false

	var hp_anterior = instancia.current_hp

	instancia.card = carta_evolucao

	instancia.current_hp = min(
		carta_evolucao.hp,
		hp_anterior + (
			carta_evolucao.hp - instancia.card.hp
		)
	)

	instancia.evoluiu_este_turno = true

	return true

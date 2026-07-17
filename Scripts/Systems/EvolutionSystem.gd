class_name EvolutionSystem

# ==================================================
# EVOLUTION SYSTEM
# Responsável por:
# - Verificar Crescimento
# - Executar Crescimento
#
# BUG CORRIGIDO: class_name estava como "GrowSystem", divergindo do
# nome do arquivo (EvolutionSystem.gd) — padronizado pra bater com o
# arquivo. Também havia uma segunda implementação de crescer(), morta
# (depois de um `return true`), que nunca executava e ainda por cima
# tinha um bug nela (calculava dano_sofrido usando instancia.card.hp
# depois que instancia.card já tinha sido reatribuído pra carta
# evoluída, então o cálculo de HP dava errado). Removida.
# ==================================================


## Regra confirmada com o time: um animal que cresceu neste turno
## PODE atacar no mesmo turno (só não pode evoluir de novo, nem pode
## evoluir se acabou de entrar em campo).
static func pode_crescer(
	instancia: AnimalInstance,
	carta_evolucao: CardResource
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

	# Verifica se a evolução corresponde ao estágio atual
	if carta_evolucao.grow_from != instancia.card.card_id:
		return false

	return true


static func crescer(
	instancia: AnimalInstance,
	carta_evolucao: CardResource
) -> bool:

	if not pode_crescer(instancia, carta_evolucao):
		return false

	var carta_antiga: CardResource = instancia.card
	var hp_atual: int = instancia.current_hp

	# A carta do estágio anterior NÃO é descartada — vai "por baixo"
	# da nova (padrão Pokémon/Digimon TCG, confirmado com o time). Só
	# é descartada de fato se o animal for nocauteado (ver
	# KnockoutSystem.processar_nocaute).
	instancia.pilha_evolucao.append(carta_antiga)

	instancia.card = carta_evolucao

	var dano_sofrido: int = carta_antiga.hp - hp_atual

	instancia.current_hp = max(
		1,
		carta_evolucao.hp - dano_sofrido
	)

	instancia.evoluiu_este_turno = true

	return true

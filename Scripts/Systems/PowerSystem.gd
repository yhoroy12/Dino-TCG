class_name EnergySystem

# ==================================================
# ENERGY SYSTEM
# Responsável por anexar/remover cartas de "força primordial"
# (energia) em animais.
#
# BUG CORRIGIDO: as funções recebiam `energia: CardResource`, mas
# cartas de energia têm super_type == "energia", ou seja, são
# EffectResource pela divisão CardResource/EffectResource do projeto.
# Isso ia estourar em runtime assim que uma energia de verdade fosse
# anexada.
# ==================================================


## Anexa uma carta de energia (EffectResource, super_type "energia")
## a um animal. Validação (1x por turno, animal pertence ao jogador
## etc.) é responsabilidade do RuleValidator — esta função assume que
## já foi validada, igual ao resto dos Systems do projeto.
static func anexar_energia(animal: AnimalInstance, energia: EffectResource) -> void:
	if animal == null or energia == null:
		return

	animal.attached_energies.append(energia)


## Remove uma energia específica de um animal (ex: efeito de carta que
## desanexa, ou animal nocauteado — nesse caso quem chama decide se a
## energia vai pro descarte).
static func remover_energia(animal: AnimalInstance, energia: EffectResource) -> bool:
	if animal == null or energia == null:
		return false

	var indice: int = animal.attached_energies.find(energia)
	if indice == -1:
		return false

	animal.attached_energies.remove_at(indice)
	return true


## Remove e retorna TODAS as energias anexadas a um animal — usado
## quando o animal é nocauteado (as energias geralmente vão junto pro
## descarte, mas quem decide o destino delas é quem chama isto).
static func remover_todas_energias(animal: AnimalInstance) -> Array[EffectResource]:
	var removidas: Array[EffectResource] = []

	if animal == null:
		return removidas

	for energia in animal.attached_energies:
		removidas.append(energia)

	animal.attached_energies.clear()
	return removidas


## Paga um custo (ex: custo de recuo) descartando exatamente as
## energias que o JOGADOR escolheu (energias_selecionadas) — nunca
## escolhe automaticamente por conta própria, porque cor/prioridade
## de qual energia descartar é decisão estratégica do jogador, não
## do System.
##
## Assume que a seleção já foi validada por
## RuleValidator.validate_retreat_cost (cobre o custo exigido e todas
## pertencem de fato ao animal) — este System só executa.
## Retorna as energias removidas, pra quem chamou (BattleManager)
## mandar pro descarte do dono.
static func pagar_custo(
	animal: AnimalInstance,
	energias_selecionadas: Array
) -> Array[EffectResource]:

	var descartadas: Array[EffectResource] = []

	if animal == null:
		return descartadas

	for energia in energias_selecionadas:
		if remover_energia(animal, energia):
			descartadas.append(energia)

	return descartadas

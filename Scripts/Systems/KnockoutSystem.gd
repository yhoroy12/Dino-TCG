# ==================================================
# Nome: KnockoutSystem
# Categoria: Systems
# Responsável pelos nocautes.
#
# Deve controlar:
# - Verificação de KO
# - Remoção do campo
# - Envio para descarte
# - Limpeza de condições
# ==================================================

class_name KnockoutSystem


# ==================================================
# VERIFICAÇÃO
# ==================================================

## Verifica se um animal está nocauteado.
static func esta_nocauteado(
	animal: AnimalInstance
) -> bool:

	if animal == null:
		return false

	return (
		animal.current_hp <= 0
		or animal.current_food <= 0
	)


## Retorna todos os animais nocauteados do jogador.
static func verificar_nocaute(
	player: PlayerState
) -> Array[AnimalInstance]:

	var nocauteados: Array[AnimalInstance] = []

	if player.ativo != null:

		if esta_nocauteado(player.ativo):
			nocauteados.append(player.ativo)

	for animal in player.banco:

		if esta_nocauteado(animal):
			nocauteados.append(animal)

	return nocauteados


# ==================================================
# PROCESSAMENTO
# ==================================================

## Processa o nocaute de um animal.
static func processar_nocaute(
	player: PlayerState,
	animal: AnimalInstance
) -> void:

	if animal == null:
		return

	# Remove condições especiais
	ConditionSystem.limpar_todas_as_condicoes(animal)

	# Move carta principal para descarte
	player.descarte.append(animal.card)

	# Move energias anexadas para descarte
	for energia in animal.attached_energies:
		player.descarte.append(energia)

	animal.attached_energies.clear()

	# Remove do campo
	if player.ativo == animal:

		player.ativo = null

	else:

		player.banco.erase(animal)


## Processa todos os nocautes encontrados.
static func processar_todos_nocautes(
	player: PlayerState
) -> Array[AnimalInstance]:

	var nocauteados = verificar_nocaute(player)

	for animal in nocauteados:
		processar_nocaute(player, animal)

	return nocauteados

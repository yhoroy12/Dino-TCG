class_name FoodSystem

# ==================================================
# FOOD SYSTEM
# Responsável por:
# - Adicionar comida
# - Consumir comida
# - Verificar fome
# ==================================================


static func alimentar(
	animal : AnimalInstance,
	quantidade : int
) -> void:
	animal.current_food += quantidade

static func consumir_comida(
	animal : AnimalInstance,
	quantidade : int
) -> void:

	animal.current_food = max(
		0,
		animal.current_food - quantidade
	)


static func possui_comida_suficiente(
	animal : AnimalInstance,
	quantidade : int
) -> bool:

	return animal.current_food >= quantidade


static func verificar_fome(
	animal : AnimalInstance
) -> bool:

	return animal.current_food <= 0


static func distribuir_comida_passiva(
	player : PlayerState
) -> void:

	if player.ativo:
		alimentar(player.ativo, 1)

	for animal in player.banco:
		alimentar(animal, 1)

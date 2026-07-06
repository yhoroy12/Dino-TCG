class_name EnergySystem

# ==================================================
# ENERGY SYSTEM
# Responsável por:
# - Anexar energias
# - Remover energias
# - Contar energias
# ==================================================


static func anexar_energia(
	animal : AnimalInstance,
	energia : CardResource
) -> bool:

	if animal == null:
		return false

	if energia == null:
		return false

	animal.attached_energies.append(energia)

	return true


static func remover_energia(
	animal : AnimalInstance,
	energia : CardResource
) -> bool:

	if animal == null:
		return false

	if energia == null:
		return false

	if !animal.attached_energies.has(energia):
		return false

	animal.attached_energies.erase(energia)

	return true


static func remover_todas_energias(
	animal : AnimalInstance
) -> void:

	animal.attached_energies.clear()


static func contar_energias(
	animal : AnimalInstance
) -> int:

	return animal.attached_energies.size()


static func contar_por_cor(
	animal : AnimalInstance
) -> Dictionary:

	return animal.contar_energias_por_cor()

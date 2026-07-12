class_name PowerSystem

# ==================================================
# Finalizado
# ENERGY SYSTEM
# Responsável por:
# - Anexar forcas
# - Remover forcas
# - Contar forcas
# ==================================================


static func anexar_forca(
	animal : AnimalInstance,
	forca : EffectResource
) -> bool:

	if animal == null:
		return false

	if forca == null:
		return false

	animal.attached_energies.append(forca)

	return true


static func remover_forca(
	animal : AnimalInstance,
	forca : EffectResource
) -> bool:

	if animal == null:
		return false

	if forca == null:
		return false

	if !animal.attached_energies.has(forca):
		return false

	animal.attached_energies.erase(forca)

	return true


static func remover_todas_forcas(
	animal : AnimalInstance
) -> void:

	animal.attached_energies.clear()


static func contar_forcas(
	animal : AnimalInstance
) -> int:

	return animal.attached_energies.size()


static func contar_por_cor(
	animal : AnimalInstance
) -> Dictionary:

	return animal.contar_forcas_por_cor()

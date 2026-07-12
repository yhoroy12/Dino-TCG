extends Node
class_name DeckRulesSystem

# ==============================================================================
# DeckRulesSystem — Sistema de Validação de Regras (core/systems/DeckRulesSystem.gd)
#
# Fonte da verdade da regra de deck. RuleValidator.validate_deck() /
# validate_deck_size() / validate_card_copies() / validate_baby_requirement()
# chamam este sistema em vez de duplicar a regra — a UI (deck_builder) usa
# este sistema direto pra feedback ao vivo; o resto do jogo passa pelo
# RuleValidator.
# ==============================================================================

const TAMANHO_DECK_VALIDO := 60

static func obter_limite_copias(card_res: CardBaseResource) -> int:
	var limite_val = card_res.get("limite_copias")
	if limite_val != null:
		return int(limite_val)

	var super_type := str(card_res.get("super_type")).strip_edges().to_lower()
	if super_type == "energia":
		return 99

	return 4


static func contar_copias(cartas: Array[CardBaseResource], card_id: String) -> int:
	var total := 0
	for carta in cartas:
		if carta.id == card_id:
			total += 1
	return total


static func validar_deck(deck_data: DeckData) -> Dictionary:
	var erros: Array[String] = []
	var possui_filhote := false
	var contador_copias: Dictionary = {}

	for carta in deck_data.cartas:
		var id = carta.id
		var stage_val = carta.get("stage") if carta.get("stage") != null else carta.get("estagio")
		var estagio := str(stage_val if stage_val != null else "").to_lower()

		contador_copias[id] = contador_copias.get(id, 0) + 1

		var limite = obter_limite_copias(carta)
		if contador_copias[id] > limite and not erros.has("Limite de cópias excedido para: " + carta.name):
			erros.append("Limite de cópias excedido para: " + carta.name)

		if "filhote" in estagio or "bebe" in estagio or "bebê" in estagio:
			possui_filhote = true

	if deck_data.cartas.size() != TAMANHO_DECK_VALIDO:
		erros.append("O deck deve conter exatamente %d cartas (Atual: %d)." % [TAMANHO_DECK_VALIDO, deck_data.cartas.size()])

	if not possui_filhote:
		erros.append("O deck precisa ter pelo menos um Dinossauro Filhote.")

	return {
		"valido": erros.is_empty(),
		"erros": erros,
		"possui_filhote": possui_filhote,
		"tamanho_valido": deck_data.cartas.size() == TAMANHO_DECK_VALIDO
	}

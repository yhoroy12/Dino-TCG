class_name DrawSystem

static func comprar_carta(player: PlayerState) -> CardResource:

	if player.deck.is_empty():
		return null
	var carta = player.deck.pop_front()
	player.mao.append(carta)
	return carta

static func buscar_cartas(
	player: PlayerState,
	filtro: Callable,
	quantidade: int = 1
) -> Array[CardResource]:

	var resultado : Array[CardResource] = []

	for carta in player.deck:

		if filtro.call(carta):
			resultado.append(carta)

			if resultado.size() >= quantidade:
				break

	return resultado
	
static func embaralhar_deck(player: PlayerState):
	player.deck.shuffle()

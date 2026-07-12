class_name DrawSystem
#SISTEMA DE COMPRA E BUSCA DE CARTAS NO DECK
#FINALIZADO

#compra a carta do topo do deck
static func comprar_carta(player: PlayerState) -> CardBaseResource:
	if player.deck.is_empty():
		return null
	var carta: CardBaseResource = player.deck.pop_front()
	player.mao.append(carta)
	return carta

#Procura uma carta no deck
static func buscar_cartas(
	player: PlayerState,
	filtro: Callable,
	quantidade: int = 1
) -> Array[CardBaseResource]:

	var resultado : Array[CardBaseResource] = []

	for carta in player.deck:

		if filtro.call(carta):
			resultado.append(carta)

			if resultado.size() >= quantidade:
				break

	return resultado

# Embaralha as cartas do deck
static func embaralhar_deck(player: PlayerState):
	player.deck.shuffle()

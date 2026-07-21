class_name DrawSystem

# ==================================================
# DRAW SYSTEM
# Responsável exclusivamente pela movimentação de cartas
# entre o Deck e a Mão do jogador.
# ==================================================

## Compra a carta do topo do deck e adiciona na mão.
static func comprar_carta(player: PlayerState) -> CardBaseResource:
	if player == null or player.deck.is_empty():
		return null
		
	var carta: CardBaseResource = player.deck.pop_front()
	player.mao.append(carta)
	return carta


## Busca cartas no deck via filtro, REMOVE do deck, ADICIONA na mão
## e EMBARALHA o deck em seguida.
static func buscar_cartas(
	player: PlayerState,
	filtro: Callable,
	quantidade: int = 1
) -> Array[CardBaseResource]:

	var resultado: Array[CardBaseResource] = []
	if player == null or player.deck.is_empty() or quantidade <= 0:
		return resultado

	# Iteramos de trás para frente para poder remover do Array sem quebrar os índices
	for i in range(player.deck.size() - 1, -1, -1):
		var carta: CardBaseResource = player.deck[i]

		if filtro.call(carta):
			resultado.append(carta)
			player.deck.remove_at(i) # Remove do deck
			player.mao.append(carta) # Adiciona na mão

			if resultado.size() >= quantidade:
				break

	# Regra essencial de TCG: buscou no deck = embaralha
	embaralhar_deck(player)

	return resultado


## Embaralha as cartas do deck.
static func embaralhar_deck(player: PlayerState) -> void:
	if player != null and not player.deck.is_empty():
		player.deck.shuffle()

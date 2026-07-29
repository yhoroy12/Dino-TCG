# ==================================================
# Nome: WinConditionSystem
# Categoria: Systems
# Responsável por validar todas as condições de vitória e empate do Prehistoric TCG.
# ==================================================
class_name WinConditionSystem

## Limite de animais nocauteados para vencer a partida
const LIMITE_NOCAUTES: int = 4

# Resultados possíveis
enum Resultado { NENHUM, VITORIA_J0, VITORIA_J1, EMPATE }


## Converte o Enum Resultado para o ID numérico do jogador (0, 1, ou -1 para Empate)
static func obter_vencedor_id(resultado: Resultado) -> int:
	match resultado:
		Resultado.VITORIA_J0: return 0
		Resultado.VITORIA_J1: return 1
		Resultado.EMPATE: return -1
		_: return -1


## 1. REGRA DE 4 NOCAUTES
## Deve ser chamada pelo KnockoutSystem toda vez que um animal é processado.
static func checar_vitoria_por_nocautes() -> Resultado:
	var j0_atingiu := GameState.nocautes_j0 >= LIMITE_NOCAUTES
	var j1_atingiu := GameState.nocautes_j1 >= LIMITE_NOCAUTES

	if j0_atingiu and j1_atingiu:
		return Resultado.EMPATE
	elif j0_atingiu:
		return Resultado.VITORIA_J0
	elif j1_atingiu:
		return Resultado.VITORIA_J1

	return Resultado.NENHUM


## 2. REGRA DE BANCO VAZIO APÓS NOCAUTE
## Deve ser chamada no TurnManager (fase_final) quando um Ativo morre.
static func checar_vitoria_por_campo_vazio() -> Resultado:
	var j0_sem_campo := GameState.obter_ativo(0) == null and GameState.obter_banco(0).is_empty()
	var j1_sem_campo := GameState.obter_ativo(1) == null and GameState.obter_banco(1).is_empty()

	if j0_sem_campo and j1_sem_campo:
		return Resultado.EMPATE
	elif j0_sem_campo:
		return Resultado.VITORIA_J1 # Jogador 1 vence pois J0 ficou sem mesa
	elif j1_sem_campo:
		return Resultado.VITORIA_J0 # Jogador 0 vence pois J1 ficou sem mesa

	return Resultado.NENHUM


## 3. REGRA DE DECKOUT (Sem cartas no baralho no início do turno)
## Deve ser chamada na fase_compra() do TurnManager antes de puxar carta.
static func checar_vitoria_por_deckout(jogador_id_da_vez: int) -> Resultado:
	var jogador_atual := GameState.get_jogador_atual()
	var jogador_adv := GameState.get_jogador_adversario()

	if jogador_atual.deck.is_empty():
		if jogador_adv.deck.is_empty():
			return Resultado.EMPATE
		
		return Resultado.VITORIA_J1 if jogador_id_da_vez == 0 else Resultado.VITORIA_J0

	return Resultado.NENHUM


## Atualiza o GameState com o fim do jogo.
## NUNCA dispara sinais diretamente para UI ou Managers.
static func processar_resultado(resultado: Resultado, motivo: String) -> bool:
	if resultado == Resultado.NENHUM:
		return false

	GameState.partida_ativa = false

	match resultado:
		Resultado.VITORIA_J0:
			GameState.vencedor = GameState.jogador_1
			print("🏆 [WinConditionSystem] Fim de jogo: Vitória do Jogador 0! Motivo: %s" % motivo)

		Resultado.VITORIA_J1:
			GameState.vencedor = GameState.jogador_2
			print("🏆 [WinConditionSystem] Fim de jogo: Vitória do Jogador 1! Motivo: %s" % motivo)

		Resultado.EMPATE:
			GameState.vencedor = null
			print("🤝 [WinConditionSystem] Fim de jogo: EMPATE! Motivo: %s" % motivo)

	return true

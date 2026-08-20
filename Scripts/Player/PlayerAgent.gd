class_name PlayerAgent
extends RefCounted
# ==================================================
# Contrato único que qualquer "decisor" de jogador (humano ou IA)
# deve implementar. BattleManager/TurnManager chamam esses métodos
# DIRETAMENTE — nunca mais via sinal broadcast pra decisão de jogador.
# ==================================================

var jogador_id: int = -1

func _init(p_jogador_id: int = -1) -> void:
	jogador_id = p_jogador_id

## Escolhe um animal do banco pra virar o novo Ativo (após nocaute).
## Retorna null se o chamador não deveria prosseguir (banco vazio já é
## tratado ANTES de chamar isso — ver resolver_promocao_pendente).
func decidir_promocao_ativo(_banco_disponivel: Array) -> AnimalInstance:
	push_error("PlayerAgent.decidir_promocao_ativo() não implementado.")
	return null

## Escolhe N CardBaseResource entre os elegíveis. Array vazio = cancelado.
func decidir_selecao_cartas(_elegiveis: Array, _quantidade: int, _contexto: String) -> Array:
	push_error("PlayerAgent.decidir_selecao_cartas() não implementado.")
	return []

## Escolhe N AnimalInstance entre os elegíveis.
func decidir_selecao_animal(_elegiveis: Array, _quantidade: int, _contexto: String) -> Array:
	push_error("PlayerAgent.decidir_selecao_animal() não implementado.")
	return []

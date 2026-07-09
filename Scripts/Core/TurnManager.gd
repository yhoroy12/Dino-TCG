# ==================================================
# Nome: TurnManager
# Categoria: Managers
# Responsável pelo fluxo dos turnos.
#
# Deve controlar:
# - Início do turno
# - Fim do turno
# - Mudança de jogador
# - Mudança de fases
# - Efeitos de início de turno
# - Efeitos de fim de turno
#
# Não deve resolver combates.
#
# Autoload (singleton), assim como GameState. NÃO guarda estado
# próprio de turno/fase — toda essa informação mora em GameState
# (única fonte da verdade). TurnManager só sabe COMO avançar
# esse estado, nunca é ele mesmo a fonte da verdade sobre o
# estado atual.
# ==================================================
extends Node


func iniciar_turno() -> void:
	GameState.fase_atual = GameState.Fase.INICIO

	_resetar_flags_turno()

	fase_compra()


func fase_compra() -> void:
	GameState.fase_atual = GameState.Fase.COMPRA

	DrawSystem.comprar_carta(GameState.get_jogador_atual())

	fase_comida()


func fase_comida() -> void:
	GameState.fase_atual = GameState.Fase.COMIDA

	FoodSystem.distribuir_comida_passiva(GameState.get_jogador_atual())

	fase_principal()


func fase_principal() -> void:
	GameState.fase_atual = GameState.Fase.PRINCIPAL

	# Nesta fase o jogador controla o jogo.
	#
	# Pode:
	# - Alimentar
	# - Energizar
	# - Crescer
	# - Recuar
	# - Usar Habilidades
	# - Jogar Vestígios
	# - Jogar Territórios
	# - Jogar Cataclismos
	#
	# O TurnManager não executa nada aqui.
	# Apenas informa que a fase atual é PRINCIPAL.


## Chamado quando o jogador decide atacar (via BattleManager/UI).
##
## IMPORTANTE: esta função NÃO encerra o turno sozinha. O ataque
## ainda precisa ser resolvido pelo BattleManager (CombatSystem +
## DamageSystem + KnockoutSystem); só DEPOIS dessa resolução o
## BattleManager deve chamar TurnManager.fase_final() explicitamente.
func fase_ataque() -> void:
	GameState.fase_atual = GameState.Fase.ATAQUE
	# A partir daqui, o BattleManager assume o controle da
	# resolução do ataque. O TurnManager espera ser chamado de volta.


func fase_final() -> void:
	GameState.fase_atual = GameState.Fase.FINAL

	_processar_fim_de_turno_dos_animais()

	_passar_turno()


# ==================================================
# FUNÇÕES PRIVADAS
# ==================================================

func _passar_turno() -> void:
	_trocar_jogador()

	GameState.turno_atual += 1

	iniciar_turno()


func _trocar_jogador() -> void:
	GameState.jogador_ativo = 1 if GameState.jogador_ativo == 0 else 0


func _resetar_flags_turno() -> void:
	GameState.energia_anexada_neste_turno = false
	GameState.recuo_realizado_neste_turno = false
	GameState.cataclismo_jogado_neste_turno = false


## Processa fim de turno de TODOS os animais em campo (ativo +
## banco) dos DOIS jogadores: condições especiais (ConditionSystem)
## e efeitos temporários (EffectSystem).
##
## Precisa rodar para os dois jogadores, não só para o jogador da
## vez, porque um animal do adversário também pode estar contando
## turnos de uma condição ou de um efeito com Escopo.TURNO_ATUAL.
##
## era_turno_do_dono diferencia os dois grupos: para os animais do
## jogador cujo turno está terminando agora, passamos true (conta
## para efeitos com Escopo.TURNOS_DO_DONO); para os animais do
## adversário, passamos false.
func _processar_fim_de_turno_dos_animais() -> void:
	var jogador_da_vez: PlayerState = GameState.get_jogador_atual()
	var jogador_adversario: PlayerState = GameState.get_jogador_adversario()

	for animal in jogador_da_vez.animais_em_campo():
		ConditionSystem.processar_fim_de_turno(animal)
		EffectSystem.processar_fim_de_turno(animal, true)

		# A partir daqui o animal deixa de ser "recém-entrado": ele
		# sobreviveu a uma troca de turno completa do próprio dono.
		# RuleValidator.validate_attack depende disso para liberar o
		# ataque em turnos seguintes.
		animal.entrou_este_turno = false

	for animal in jogador_adversario.animais_em_campo():
		ConditionSystem.processar_fim_de_turno(animal)
		EffectSystem.processar_fim_de_turno(animal, false)

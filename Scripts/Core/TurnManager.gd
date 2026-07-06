# ==================================================
# Nome: TurnManager
# Categoria: Core
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
# ==================================================

enum {INICIO, COMPRA, COMIDA, PRINCIPAL, ATAQUE, FINAL}
var fase = INICIO

func iniciar_turno():
	# Define a fase inicial do turno
	fase = INICIO

	# Reseta flags de controle do turno
	_resetar_flags_turno(GameState)

	# Avança para a próxima fase
	fase_compra()
	
func fase_compra():
	# Atualiza fase
	fase = COMPRA

	# Compra a carta do turno
	DrawSystem.comprar_carta(
		GameState.get_jogador_atual()
	)

	# Próxima fase
	fase_comida()
func fase_comida():
	# Atualiza fase
	fase = COMIDA

	# Distribui comida passiva
	FoodSystem.distribuir_comida_passiva(
		GameState.get_jogador_atual()
	)

	# Próxima fase
	fase_principal()
	
func fase_principal():
	# Atualiza fase
	fase = PRINCIPAL

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
func fase_ataque():
	# Atualiza fase
	fase = ATAQUE

	# A UI/BattleManager escolhe e executa o ataque.
	# Após a resolução do ataque o turno termina.
	fase_final()
	
func fase_final():
	# Atualiza fase
	fase = FINAL

	# Processa condições especiais
	ConditionSystem.processar_fim_turno(
		GameState
	)

	# Passa o turno
	_passar_turno(GameState)
	

func _passar_turno(game_state):
	_trocar_jogador(game_state)

	game_state.turno_atual += 1

	iniciar_turno()

# ==================================================
# FUNÇÕES PRIVADAS
# ==================================================
func _trocar_jogador(game_state):
	if game_state.jogador_ativo == 0:
		game_state.jogador_ativo = 1
	else:
		game_state.jogador_ativo = 0


func _resetar_flags_turno(game_state):
	game_state.energia_anexada_neste_turno = false
	game_state.recuo_realizado_neste_turno = false
	game_state.cataclismo_jogado_neste_turno = false

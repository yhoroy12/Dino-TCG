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


# ==================================================
# SINAIS
# Fluxo puro, sem carregar dado além do necessário pra UI
# saber "o que" e "de quem". TurnManager continua sem
# guardar estado próprio — quem quiser saber a fase ou o
# turno atual lê em GameState, como sempre.
# ==================================================

signal turno_iniciado(jogador_id: int)
signal turno_encerrado(jogador_id: int)


func iniciar_turno() -> void:
	GameState.fase_atual = GameState.Fase.INICIO

	_resetar_flags_turno()

	turno_iniciado.emit(GameState.jogador_ativo)

	fase_compra()


func fase_compra() -> void:
	GameState.fase_atual = GameState.Fase.COMPRA

	DrawSystem.comprar_carta(GameState.get_jogador_atual())

	fase_comida()


func fase_comida() -> void:
	GameState.fase_atual = GameState.Fase.COMIDA

	# Modelo B (confirmado com o time): o jogador ganha pontos no
	# POOL (comida_disponivel), cumulativos — a distribuição pros
	# animais é manual, feita pelo jogador na Fase Principal via
	# BattleManager.processar_acao("distribuir_comida", ...).
	FoodSystem.ganhar_pool_comida(GameState.get_jogador_atual())

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

	# Emitido ANTES de trocar o jogador ativo: turno_encerrado deve
	# informar quem estava terminando o turno, não quem está começando.
	turno_encerrado.emit(GameState.jogador_ativo)

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

	# BUG CORRIGIDO: evoluiu_este_turno nunca era resetado depois de
	# setado true em EvolutionSystem.crescer() — na prática, um animal
	# que evoluísse uma vez nunca mais poderia evoluir de novo no
	# resto da partida. Reseta pros animais do jogador cujo turno está
	# começando agora (GameState.jogador_ativo já foi trocado por
	# _trocar_jogador antes desta função rodar).
	for animal in GameState.get_jogador_atual().animais_em_campo():
		animal.evoluiu_este_turno = false


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

	# Regra confirmada com o time: a redução passiva de 1 ponto de
	# comida por turno só se aplica ao Animal ATIVO do jogador cujo
	# turno está terminando — o Banco Reserva nunca perde comida
	# passivamente (só por efeito de carta/habilidade explícito).
	FoodSystem.aplicar_reducao_passiva(jogador_da_vez)

	# Checa nocautes causados pela redução de comida acima (fome).
	# Nocautes por dano de combate já são resolvidos na hora do
	# ataque, pelo BattleManager — esta chamada aqui cobre
	# especificamente o gatilho de fim de turno.
	KnockoutSystem.processar_todos_nocautes(jogador_da_vez)

# ==================================================
# Nome: BattleManager
# Categoria: Core / Managers
# Responsável por ser o ÚNICO ponto de entrada para toda ação de
# jogador durante a Fase Principal e a Fase de Ataque.
#
# Fluxo padrão de qualquer ação, sem exceção:
#   1. VALIDA  -> RuleValidator.validate_*
#   2. APLICA  -> System correspondente (FoodSystem, EnergySystem,
#                 EvolutionSystem, CombatSystem + DamageSystem, etc.)
#   3. MARCA FLAG DE TURNO, se a ação for limitada (energia, recuo)
#
# A UI (mesa_jogador.gd) nunca decide se uma ação é válida — ela só
# emite `acao_jogador_solicitada(tipo_acao, dados)`. Quem escuta esse
# sinal (a cena de batalha) deve chamar
# BattleManager.processar_acao(tipo_acao, dados) e usar o resultado
# pra re-renderizar (organizar_cartas_nas_zonas) ou mostrar erro.
#
# Autoload (singleton), mesmo padrão de GameState/TurnManager/SetupManager.
# NÃO guarda estado próprio da partida — lê e escreve em GameState/
# PlayerState, que continuam sendo a única fonte da verdade.
# ==================================================
extends Node


# ==================================================
# SINAIS
# ==================================================

## Emitido ao final de QUALQUER processar_acao — sucesso ou falha.
## A UI escuta isso pra re-renderizar zonas e/ou mostrar feedback de
## erro (ex: texto flutuante "Banco cheio").
signal acao_resolvida(tipo_acao: String, sucesso: bool, motivo: String, dados: Dictionary)
signal ataque_executado(atacante: AnimalInstance, defensor: AnimalInstance, ataque: CardResource, dano: int)
signal ataque_falhou_paralisia(atacante: AnimalInstance)

# ==================================================
# API PÚBLICA — FUNIL ÚNICO
# ==================================================

## Ponto de entrada único pra qualquer ação de jogador na Fase
## Principal ou de Ataque. Retorna um Dictionary {"sucesso": bool,
## "motivo": String} — "motivo" é sempre preenchido em caso de falha,
## pra UI poder mostrar um feedback específico.
func processar_acao(tipo_acao: String, dados: Dictionary) -> Dictionary:
	var resultado: Dictionary

	match tipo_acao:
		"jogar_para_banco":
			resultado = _jogar_para_banco(dados)

		"crescer":
			resultado = _crescer(dados)

		"anexar_energia":
			resultado = _anexar_energia(dados)

		"distribuir_comida":
			resultado = _distribuir_comida(dados)

		"recuar":
			resultado = _recuar(dados)

		"promover_ativo":
			resultado = _promover_ativo(dados)

		"atacar":
			resultado = _atacar(dados)

		"jogar_territorio", "jogar_vestigio", "jogar_cataclismo":
			# Prioridades 5, 6 e 7 do projeto — ainda não chegaram na
			# ordem. RuleValidator já tem os esqueletos
			# (validate_territory, validate_fossil_card,
			# validate_cataclysm) prontos pra quando chegar a vez.
			resultado = {"sucesso": false, "motivo": "ainda_nao_implementado"}

		"usar_habilidade":
			# Depende de um interpretador de AbilityResource que ainda
			# não existe no projeto — fora do escopo do Turno 1.
			resultado = {"sucesso": false, "motivo": "ainda_nao_implementado"}

		_:
			resultado = {"sucesso": false, "motivo": "acao_desconhecida"}

	acao_resolvida.emit(tipo_acao, resultado["sucesso"], resultado["motivo"], dados)
	return resultado


# ==================================================
# BANCO RESERVA — colocar animal bebê da mão
# ==================================================

## dados: {"indice_mao": int, "carta": CardBaseResource}
func _jogar_para_banco(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var indice_mao: int = dados.get("indice_mao", -1)
	var carta: CardBaseResource = dados.get("carta")

	if indice_mao < 0 or indice_mao >= jogador.mao.size():
		return {"sucesso": false, "motivo": "indice_mao_invalido"}

	if jogador.mao[indice_mao] != carta:
		return {"sucesso": false, "motivo": "carta_nao_confere"}

	if not RuleValidator.validate_bench_placement(carta, jogador):
		return {"sucesso": false, "motivo": "colocacao_invalida"}

	jogador.mao.remove_at(indice_mao)

	var instancia := AnimalInstance.new(carta)
	instancia.entrou_este_turno = true # Marcação interna para a regra do EvolutionSystem
	jogador.banco.append(instancia)

	return {"sucesso": true, "motivo": ""}

# ==================================================
# CRESCIMENTO — evoluir um animal em campo
# ==================================================

## dados: {"indice_mao": int, "carta_evolucao": CardResource, "instancia": AnimalInstance}
##
## A carta do estágio anterior não é descartada aqui — EvolutionSystem.crescer()
## já cuida de empilhá-la em instancia.pilha_evolucao (padrão Pokémon/
## Digimon TCG, confirmado com o time). Ela só vai pro descarte de
## fato se o animal for nocauteado (KnockoutSystem.processar_nocaute).
func _crescer(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var indice_mao: int = dados.get("indice_mao", -1)
	var carta_evolucao: CardResource = dados.get("carta_evolucao")
	var instancia: AnimalInstance = dados.get("instancia")

	if indice_mao < 0 or indice_mao >= jogador.mao.size():
		return {"sucesso": false, "motivo": "indice_mao_invalido"}

	if jogador.mao[indice_mao] != carta_evolucao:
		return {"sucesso": false, "motivo": "carta_nao_confere"}

	if not jogador.animais_em_campo().has(instancia):
		return {"sucesso": false, "motivo": "animal_fora_de_campo"}

	if not RuleValidator.validate_evolution(instancia, carta_evolucao):
		return {"sucesso": false, "motivo": "evolucao_invalida"}

	EvolutionSystem.crescer(instancia, carta_evolucao)
	jogador.mao.remove_at(indice_mao)

	return {"sucesso": true, "motivo": ""}


# ==================================================
# ENERGIA — anexar força primordial (1x por turno)
# ==================================================

## dados: {"indice_mao": int, "carta": EffectResource, "animal": AnimalInstance}
func _anexar_energia(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var indice_mao: int = dados.get("indice_mao", -1)
	var carta: EffectResource = dados.get("carta")
	var animal: AnimalInstance = dados.get("animal")

	if indice_mao < 0 or indice_mao >= jogador.mao.size():
		return {"sucesso": false, "motivo": "indice_mao_invalido"}

	if jogador.mao[indice_mao] != carta:
		return {"sucesso": false, "motivo": "carta_nao_confere"}

	if not RuleValidator.validate_energy_attachment(jogador, animal, carta):
		return {"sucesso": false, "motivo": "anexacao_invalida"}

	EnergySystem.anexar_energia(animal, carta)
	jogador.mao.remove_at(indice_mao)
	GameState.energia_anexada_neste_turno = true

	return {"sucesso": true, "motivo": ""}


# ==================================================
# COMIDA — distribuir pontos do pool pra um animal
# ==================================================

## dados: {"animal": AnimalInstance, "quantidade": int}
func _distribuir_comida(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var animal: AnimalInstance = dados.get("animal")
	var quantidade: int = dados.get("quantidade", 0)

	if not RuleValidator.validate_food_distribution(jogador, animal, quantidade):
		return {"sucesso": false, "motivo": "distribuicao_invalida"}

	FoodSystem.distribuir_comida(jogador, animal, quantidade)

	return {"sucesso": true, "motivo": ""}


# ==================================================
# RECUO — trocar o Ativo por um animal do Banco (1x por turno,
# pagando o custo de retreat_cost da carta do Ativo em energias
# descartadas)
# ==================================================

## dados: {"substituto": AnimalInstance, "energias_para_descarte": Array}
##
## "energias_para_descarte" é a escolha do JOGADOR de quais energias
## anexadas ao Ativo serão descartadas pra pagar o custo — a UI deve
## deixar o jogador selecionar isso quando o custo exigir mais de uma
## opção possível (ex: custo pede 1 incolor e o animal tem 2 energias
## de cores diferentes anexadas: qualquer uma serve, mas quem escolhe
## é o jogador).
func _recuar(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var animal_atual: AnimalInstance = jogador.ativo
	var substituto: AnimalInstance = dados.get("substituto")
	var energias_para_descarte: Array = dados.get("energias_para_descarte", [])

	if not RuleValidator.validate_retreat(animal_atual, jogador, energias_para_descarte):
		return {"sucesso": false, "motivo": "recuo_invalido"}

	if not RuleValidator.validate_retreat_target(jogador, substituto):
		return {"sucesso": false, "motivo": "substituto_invalido"}

	# Paga o custo: descarta exatamente as energias que o jogador
	# escolheu (já validadas acima como suficientes pro custo).
	var descartadas: Array[EffectResource] = EnergySystem.pagar_custo(animal_atual, energias_para_descarte)
	jogador.descarte.append_array(descartadas)

	jogador.banco.erase(substituto)
	jogador.banco.append(animal_atual)
	jogador.ativo = substituto

	GameState.recuo_realizado_neste_turno = true

	return {"sucesso": true, "motivo": ""}


# ==================================================
# PROMOÇÃO FORÇADA — Ativo nocauteado precisa de substituto
# Diferente de "recuar": não custa nada, não tem limite de 1x/turno,
# e pode ser necessária no turno do ADVERSÁRIO (quando o ataque dele
# nocauteia seu Ativo). Por isso não usa GameState.jogador_ativo,
# recebe o jogador explicitamente em `dados`.
# ==================================================

## dados: {"jogador_id": int, "substituto": AnimalInstance}
func _promover_ativo(dados: Dictionary) -> Dictionary:
	var jogador_id: int = dados.get("jogador_id", -1)# Quem está promovendo
	var substituto: AnimalInstance = dados.get("substituto")# Qual animal do banco está subindo
	
	# 1. Garante que o jogador que está tentando promover é quem REALMENTE precisa promover
	if GameState.jogador_sem_ativo != jogador_id:
		return {"sucesso": false, "motivo": "nao_e_sua_vez_de_promover"}
	
	if jogador_id != 0 and jogador_id != 1:
		return {"sucesso": false, "motivo": "jogador_invalido"}

	var jogador: PlayerState = GameState.jogador_1 if jogador_id == 0 else GameState.jogador_2

	if jogador.ativo != null:
		return {"sucesso": false, "motivo": "ativo_ja_preenchido"}

	if not RuleValidator.validate_retreat_target(jogador, substituto):
		return {"sucesso": false, "motivo": "substituto_invalido"}
	
	# Realiza a promoção física
	jogador.banco.erase(substituto)
	jogador.ativo = substituto
	# Resolvido o bloqueio! Ninguém mais está sem ativo
	GameState.jogador_sem_ativo = -1
	
	# Determina como o fluxo de turnos deve prosseguir baseado em QUANDO ocorreu o nocaute:
	if GameState.fase_atual == GameState.Fase.ATAQUE:
		# Se morreu no ataque, finaliza o combate e roda a Fase Final (venenos, fim de turno, etc.)
		TurnManager.fase_final()
	elif GameState.fase_atual == GameState.Fase.FINAL:
		# Se morreu na fase final (ex: fome), executa o encerramento que havia sido pausado
		TurnManager._encerrar_fase_final_e_passar_turno()
	
	return {"sucesso": true, "motivo": ""}


# ==================================================
# ATAQUE — encerra o turno, sempre (com sucesso ou falha por
# paralisia; só NÃO encerra se a declaração do ataque nem for válida)
# ==================================================

## dados: {"ataque": CardResource}
func _atacar(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var adversario: PlayerState = GameState.get_jogador_adversario()
	var atacante: AnimalInstance = jogador.ativo
	var ataque: CardResource = dados.get("ataque")

	if not RuleValidator.validate_attack(atacante, ataque):
		return {"sucesso": false, "motivo": "ataque_invalido"}

	# Transição de Fase
	TurnManager.fase_ataque()

	# Checagem de Paralisia
	if not ConditionSystem.rodar_moeda_paralisia(atacante):
		# Emite o sinal do PRÓPRIO BattleManager para a mesa tocar o som/animação de erro
		ataque_falhou_paralisia.emit(atacante)
		TurnManager.fase_final()
		return {"sucesso": true, "motivo": "paralisado_falhou", "dano_causado": 0}

	var defensor: AnimalInstance = adversario.ativo
	var dano: int = CombatSystem.calcular_dano(atacante, defensor, ataque)

	# Aplicação de dano e emissão do sinal do PRÓPRIO BattleManager
	DamageSystem.aplicar_dano(defensor, dano)
	ataque_executado.emit(atacante, defensor, ataque, dano)

	var id_jogador_atual: int = GameState.jogador_ativo
	var id_adversario: int = 1 if id_jogador_atual == 0 else 0

	# Processa nocautes
	TurnManager.atualizar_sistema_de_nocautes(jogador, id_jogador_atual)
	TurnManager.atualizar_sistema_de_nocautes(adversario, id_adversario)

	# Trava do jogo se alguém precisar promover um ativo do banco
	if GameState.jogador_sem_ativo != -1:
		return {
			"sucesso": true, 
			"motivo": "",
			"status": "aguardando_promocao", 
			"jogador_bloqueado": GameState.jogador_sem_ativo,
			"dano_causado": dano
		}
		
	# Encerramento limpo do turno
	TurnManager.fase_final()

	return {"sucesso": true, "motivo": "", "dano_causado": dano}

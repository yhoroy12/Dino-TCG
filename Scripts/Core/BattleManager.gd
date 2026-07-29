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
	print("⚔️ [BattleManager] Solicitação de ação recebida: '%s' | Jogador Ativo ID: %d" % [tipo_acao, GameState.jogador_ativo])
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

	if resultado.get("sucesso", false):
		print("✅ [BattleManager] Ação '%s' EXECUTADA COM SUCESSO." % tipo_acao)
	else:
		print("❌ [BattleManager] Ação '%s' FALHOU. Motivo: '%s'" % [tipo_acao, resultado.get("motivo", "")])

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

	var nome_carta: String = carta.name if carta != null else "Nula"
	print("🃏 [BattleManager] Tentando jogar para o banco: '%s' (Índice da mão: %d) | Jogador ID: %d" % [nome_carta, indice_mao, jogador.id])

	if indice_mao < 0 or indice_mao >= jogador.mao.size():
		print("⚠️ [BattleManager] Falha ao jogar no banco: índice da mão inválido (%d)." % indice_mao)
		return {"sucesso": false, "motivo": "indice_mao_invalido"}

	if jogador.mao[indice_mao] != carta:
		print("⚠️ [BattleManager] Falha ao jogar no banco: carta no índice %d não corresponde à carta informada." % indice_mao)
		return {"sucesso": false, "motivo": "carta_nao_confere"}

	if not RuleValidator.validate_bench_placement(carta, jogador):
		print("⚠️ [BattleManager] Falha ao jogar no banco: validação de regra recusou a colocação.")
		return {"sucesso": false, "motivo": "colocacao_invalida"}

	jogador.mao.remove_at(indice_mao)

	var instancia := AnimalInstance.new(carta)
	instancia.entrou_este_turno = true # Marcação interna para a regra do EvolutionSystem
	GameState.obter_banco(jogador.id).append(instancia)

	print("🐾 [BattleManager] Animal '%s' baixado no banco com sucesso. Total no banco: %d" % [nome_carta, GameState.obter_banco(jogador.id).size()])
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

	var nome_evo: String = carta_evolucao.name if carta_evolucao != null else "Nula"
	var nome_alvo: String = instancia.card.name if (instancia != null and instancia.card != null) else "Nulo"
	print("🌱 [BattleManager] Tentando evoluir '%s' para '%s' (Índice da mão: %d) | Jogador ID: %d" % [nome_alvo, nome_evo, indice_mao, jogador.id])

	if indice_mao < 0 or indice_mao >= jogador.mao.size():
		print("⚠️ [BattleManager] Falha na evolução: índice da mão inválido (%d)." % indice_mao)
		return {"sucesso": false, "motivo": "indice_mao_invalido"}

	if jogador.mao[indice_mao] != carta_evolucao:
		print("⚠️ [BattleManager] Falha na evolução: carta no índice %d não confere com a evolução esperada." % indice_mao)
		return {"sucesso": false, "motivo": "carta_nao_confere"}

	if not GameState.obter_animais_em_campo(jogador.id).has(instancia):
		print("⚠️ [BattleManager] Falha na evolução: animal alvo '%s' não está no campo." % nome_alvo)
		return {"sucesso": false, "motivo": "animal_fora_de_campo"}

	if not RuleValidator.validate_evolution(instancia, carta_evolucao):
		print("⚠️ [BattleManager] Falha na evolução: regra de evolução recusada pelo RuleValidator.")
		return {"sucesso": false, "motivo": "evolucao_invalida"}

	EvolutionSystem.crescer(instancia, carta_evolucao)
	jogador.mao.remove_at(indice_mao)

	print("✨ [BattleManager] Evolução concluída! '%s' agora é '%s'." % [nome_alvo, nome_evo])
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

	var nome_energia: String = carta.name if carta != null else "Nula"
	var nome_alvo: String = animal.card.name if (animal != null and animal.card != null) else "Nulo"
	print("⚡ [BattleManager] Tentando anexar energia '%s' em '%s' | Jogador ID: %d" % [nome_energia, nome_alvo, jogador.id])

	if indice_mao < 0 or indice_mao >= jogador.mao.size():
		print("⚠️ [BattleManager] Falha ao anexar energia: índice da mão inválido (%d)." % indice_mao)
		return {"sucesso": false, "motivo": "indice_mao_invalido"}

	if jogador.mao[indice_mao] != carta:
		print("⚠️ [BattleManager] Falha ao anexar energia: carta na mão não confere.")
		return {"sucesso": false, "motivo": "carta_nao_confere"}

	if not RuleValidator.validate_energy_attachment(jogador, animal, carta):
		print("⚠️ [BattleManager] Falha ao anexar energia: regra de anexação recusada.")
		return {"sucesso": false, "motivo": "anexacao_invalida"}

	EnergySystem.anexar_energia(animal, carta)
	jogador.mao.remove_at(indice_mao)
	GameState.energia_anexada_neste_turno = true

	print("🔋 [BattleManager] Energia '%s' anexada com sucesso em '%s'." % [nome_energia, nome_alvo])
	return {"sucesso": true, "motivo": ""}


# ==================================================
# COMIDA — distribuir pontos do pool pra um animal
# ==================================================

## dados: {"animal": AnimalInstance, "quantidade": int}
func _distribuir_comida(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var animal: AnimalInstance = dados.get("animal")
	var quantidade: int = dados.get("quantidade", 0)

	var nome_alvo: String = animal.card.name if (animal != null and animal.card != null) else "Nulo"
	print("🍖 [BattleManager] Tentando distribuir %d ponto(s) de comida para '%s' | Jogador ID: %d" % [quantidade, nome_alvo, jogador.id])

	if not RuleValidator.validate_food_distribution(jogador, animal, quantidade):
		print("⚠️ [BattleManager] Falha ao distribuir comida: quantidade ou regra inválida.")
		return {"sucesso": false, "motivo": "distribuicao_invalida"}

	FoodSystem.distribuir_comida(jogador, animal, quantidade)

	print("🍖 [BattleManager] %d de comida fornecido(s) para '%s'." % [quantidade, nome_alvo])
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
	var animal_atual: AnimalInstance = GameState.obter_ativo(jogador.id)
	var substituto: AnimalInstance = dados.get("substituto")
	var energias_para_descarte: Array = dados.get("energias_para_descarte", [])

	var nome_atual: String = animal_atual.card.name if (animal_atual != null and animal_atual.card != null) else "Nulo"
	var nome_substituto: String = substituto.card.name if (substituto != null and substituto.card != null) else "Nulo"
	print("🏃 [BattleManager] Tentando recuar ativo '%s' por '%s' do banco | Jogador ID: %d" % [nome_atual, nome_substituto, jogador.id])

	if not RuleValidator.validate_retreat(animal_atual, jogador, energias_para_descarte):
		print("⚠️ [BattleManager] Falha ao recuar: validação do custo/condição de recuo falhou.")
		return {"sucesso": false, "motivo": "recuo_invalido"}

	if not RuleValidator.validate_retreat_target(jogador, substituto):
		print("⚠️ [BattleManager] Falha ao recuar: substituto no banco inválido.")
		return {"sucesso": false, "motivo": "substituto_invalido"}

	# Paga o custo: descarta exatamente as energias que o jogador
	# escolheu (já validadas acima como suficientes pro custo).
	var descartadas: Array[EffectResource] = EnergySystem.pagar_custo(animal_atual, energias_para_descarte)
	GameState.obter_descarte(jogador.id).append_array(descartadas)

	# Trocar as posições
	GameState.obter_banco(jogador.id).erase(substituto)
	GameState.obter_banco(jogador.id).append(animal_atual)
	
	# Modificar a variável raiz no GameState
	if jogador.id == 0:
		GameState.ativo_j0 = substituto
	else:
		GameState.ativo_j1 = substituto

	GameState.recuo_realizado_neste_turno = true

	print("🔄 [BattleManager] Recuo efetuado! Novo Ativo: '%s'. Antigo Ativo '%s' movido para o banco." % [nome_substituto, nome_atual])
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
	
	var nome_substituto: String = substituto.card.name if (substituto != null and substituto.card != null) else "Nulo"
	print("🚨 [BattleManager] Tentando promover '%s' do banco a novo Ativo | Jogador Solicitante ID: %d" % [nome_substituto, jogador_id])

	# 1. Garante que o jogador que está tentando promover é quem REALMENTE precisa promover
	if GameState.jogador_sem_ativo != jogador_id:
		print("⚠️ [BattleManager] Promoção recusada: O jogador ID %d não é quem precisa promover no momento (Esperado ID: %d)." % [jogador_id, GameState.jogador_sem_ativo])
		return {"sucesso": false, "motivo": "nao_e_sua_vez_de_promover"}
	
	if jogador_id != 0 and jogador_id != 1:
		print("⚠️ [BattleManager] Promoção recusada: jogador_id inválido (%d)." % jogador_id)
		return {"sucesso": false, "motivo": "jogador_invalido"}

	var jogador: PlayerState = GameState.jogador_1 if jogador_id == 0 else GameState.jogador_2

	# CORREÇÃO 1: Consultando o ativo diretamente no GameState, não no PlayerState
	if GameState.obter_ativo(jogador_id) != null:
		print("⚠️ [BattleManager] Promoção recusada: O jogador ID %d já possui um ativo na mesa." % jogador_id)
		return {"sucesso": false, "motivo": "ativo_ja_preenchido"}

	if not RuleValidator.validate_retreat_target(jogador, substituto):
		print("⚠️ [BattleManager] Promoção recusada: O animal substituto não é um alvo válido no banco.")
		return {"sucesso": false, "motivo": "substituto_invalido"}
	
	# CORREÇÃO 2: Removendo do banco pelo GameState
	GameState.obter_banco(jogador_id).erase(substituto)
	
	# CORREÇÃO 3: Atribuindo o ativo à variável correta no GameState
	if jogador_id == 0:
		GameState.ativo_j0 = substituto
	else:
		GameState.ativo_j1 = substituto
		
	# Resolvido o bloqueio! Ninguém mais está sem ativo
	GameState.jogador_sem_ativo = -1
	
	print("🌟 [BattleManager] Promoção concluída! Jogador %d agora tem '%s' como Ativo." % [jogador_id, nome_substituto])

	# Determina como o fluxo de turnos deve prosseguir baseado em QUANDO ocorreu o nocaute:
	if GameState.fase_atual == GameState.Fase.ATAQUE:
		print("➡️ [BattleManager] Nocaute ocorreu na Fase de Ataque. Chamando TurnManager.fase_final()...")
		# Se morreu no ataque, finaliza o combate e roda a Fase Final (venenos, fim de turno, etc.)
		TurnManager.fase_final()
	elif GameState.fase_atual == GameState.Fase.FINAL:
		print("➡️ [BattleManager] Nocaute ocorreu na Fase Final. Desbloqueando encerramento de turno...")
		# Se morreu na fase final (ex: fome), executa o encerramento que havia sido pausado
		TurnManager._encerrar_fase_final_e_passar_turno()
	
	return {"sucesso": true, "motivo": ""}

# ==================================================
# ATAQUE — encerra o turno, sempre (com sucesso ou falha por
# paralisia; só NÃO encerra se a declaração do ataque nem for válida)
# ==================================================

## dados: {"ataque": CardResource}
# ==================================================
# ATAQUE — encerra o turno, sempre (com sucesso ou falha por
# paralisia; só NÃO encerra se a declaração do ataque nem for válida)
# FLUXO DO ATAQUE:
# UI -> [solicita] -> BattleManager -> [1. Valida] -> RuleValidator -> [2. Calcula] -> CombatSystem -> [3. Aplica Dano/Status] -> DamageSystem / ConditionSystem -> [4. Nocaute/Turno] -> TurnManager
# ==================================================

## dados: {"ataque": CardResource}
func _atacar(dados: Dictionary) -> Dictionary:
	var jogador: PlayerState = GameState.get_jogador_atual()
	var adversario: PlayerState = GameState.get_jogador_adversario()
	var atacante: AnimalInstance = GameState.obter_ativo(jogador.id)
	var ataque: CardResource = dados.get("ataque")

	var nome_atacante: String = atacante.card.name if (atacante != null and atacante.card != null) else "Nulo"
	var nome_ataque: String = ataque.name if ataque != null else "Nulo"
	print("⚔️ [BattleManager] Tentando declarar ataque '%s' com '%s' | Atacante ID: %d" % [nome_ataque, nome_atacante, jogador.id])

	# 1. Validação detalhada via RuleValidator (Passo 2)
	var validacao := RuleValidator.validar_atacar(jogador.id)
	if not validacao["sucesso"]:
		print("⚠️ [BattleManager] Ataque recusado pelo RuleValidator: %s" % validacao["motivo"])
		return validacao

	# 2. Marca a flag para impedir múltiplos ataques no mesmo turno
	atacante.ja_atacou_este_turno = true

	# 3. Transição de Fase
	TurnManager.fase_ataque()

	# 4. Checagem de Paralisia (Teste da Moeda)
	if not ConditionSystem.rodar_moeda_paralisia(atacante):
		print("💫 [BattleManager] Atacante '%s' está paralisado e falhou na moeda! Ataque cancelado." % nome_atacante)
		ataque_falhou_paralisia.emit(atacante)
		TurnManager.fase_final()
		return {"sucesso": true, "motivo": "paralisado_falhou", "dano_causado": 0}

	var defensor: AnimalInstance = GameState.obter_ativo(adversario.id)
	var nome_defensor: String = defensor.card.name if (defensor != null and defensor.card != null) else "Nulo"
	
	# 5. Cálculo e Aplicação de Dano (Esteira de Combate)
	var dano: int = CombatSystem.calcular_dano(atacante, defensor, ataque)
	print("💥 [BattleManager] Ataque validado! '%s' ataca '%s' causando %d de dano." % [nome_atacante, nome_defensor, dano])

	DamageSystem.aplicar_dano(defensor, dano)

	# 6. Aplicação de Condição Especial se a carta definir mec_status_name
	_aplicar_status_do_ataque(defensor, ataque)

	# 7. Notificação para UI/Mesa
	ataque_executado.emit(atacante, defensor, ataque, dano)

	# 8. Processamento de Nocautes
	var id_jogador_atual: int = GameState.jogador_ativo
	var id_adversario: int = 1 if id_jogador_atual == 0 else 0

	TurnManager.atualizar_sistema_de_nocautes(jogador, id_jogador_atual)
	TurnManager.atualizar_sistema_de_nocautes(adversario, id_adversario)

	# 9. Trava do jogo se alguém precisar promover um ativo do banco
	if GameState.jogador_sem_ativo != -1:
		print("🚨 [BattleManager] Ação de ataque resultou em nocaute! Jogo aguardando promoção para Jogador ID: %d" % GameState.jogador_sem_ativo)
		return {
			"sucesso": true, 
			"motivo": "",
			"status": "aguardando_promocao", 
			"jogador_bloqueado": GameState.jogador_sem_ativo,
			"dano_causado": dano
		}
		
	# 10. Encerramento do turno
	print("🏁 [BattleManager] Ataque finalizado com sucesso. Encaminhando para fase_final().")
	TurnManager.fase_final()

	return {"sucesso": true, "motivo": "", "dano_causado": dano}


## Converte o texto da carta (mec_status_name) no Enum do ConditionSystem e o aplica ao defensor
func _aplicar_status_do_ataque(defensor: AnimalInstance, ataque: CardResource) -> void:
	if defensor == null or ataque == null or ataque.mec_status_name.is_empty():
		return

	var status_str := ataque.mec_status_name.to_lower().strip_edges()
	var tipo_condicao := ConditionSystem.Tipo.NENHUMA

	match status_str:
		"adormecido", "sono":
			tipo_condicao = ConditionSystem.Tipo.ADORMECIDO
		"paralisado", "paralisia":
			tipo_condicao = ConditionSystem.Tipo.PARALISADO
		"envenenado", "veneno":
			tipo_condicao = ConditionSystem.Tipo.ENVENENADO
		"sangrando", "sangramento":
			tipo_condicao = ConditionSystem.Tipo.SANGRANDO
		"condenado", "condenacao":
			tipo_condicao = ConditionSystem.Tipo.CONDENADO

	if tipo_condicao != ConditionSystem.Tipo.NENHUMA:
		ConditionSystem.aplicar_condicao(defensor, tipo_condicao)
		print("🧪 [BattleManager] Status '%s' aplicado com sucesso a '%s'." % [status_str, defensor.card.name])

# ==================================================
# Nome: RuleValidator
# Categoria: Core
# Responsável por validar TODAS as regras oficiais do Dino TCG.
#
# Não altera estado da partida.
# Não compra cartas, não aplica dano, não move cartas.
# Apenas verifica se uma ação é válida segundo o Rulebook.
# ==================================================
class_name RuleValidator

# ==================================================
# REGRAS DE BARALHO
# ==================================================

static func validate_deck(deck: DeckData) -> Dictionary:
	if deck == null:
		return {"valido": false, "motivo": "Baralho nulo."}
	return DeckRulesSystem.validar_deck(deck)


# ==================================================
# BANCO RESERVA
# ==================================================

const TAMANHO_MAXIMO_BANCO: int = 4

static func validar_banco(card: CardResource, player: PlayerState) -> Dictionary:
	if player == null or card == null:
		return {"sucesso": false, "motivo": "Parâmetros inválidos."}

	if card.super_type.to_lower() != "animal":
		return {"sucesso": false, "motivo": "Apenas cartas de Animal podem ir para o banco."}

	if card.stage.to_lower() != "filhote":
		return {"sucesso": false, "motivo": "Apenas animais Filhotes podem ser baixados diretamente."}

	if GameState.obter_banco(player.id).size() >= TAMANHO_MAXIMO_BANCO:
		return {"sucesso": false, "motivo": "Banco reserva está cheio (máximo 4)."}

	return {"sucesso": true, "motivo": "Posicionamento no banco autorizado."}


# ==================================================
# EVOLUÇÃO
# ==================================================

static func validar_evolucao(instancia: AnimalInstance, nova_carta: CardResource) -> Dictionary:
	if instancia == null or nova_carta == null:
		return {"sucesso": false, "motivo": "Instância de animal ou carta inválida."}

	if not EvolutionSystem.pode_crescer(instancia, nova_carta):
		return {"sucesso": false, "motivo": "Evolução incompatível ou requisitos não atendidos."}

	return {"sucesso": true, "motivo": "Evolução autorizada."}


# ==================================================
# ENERGIAS
# ==================================================

static func validar_anexar_energia(player: PlayerState, animal: AnimalInstance, energy: EffectResource) -> Dictionary:
	if player == null or animal == null or energy == null:
		return {"sucesso": false, "motivo": "Parâmetros inválidos."}

	if energy.super_type.to_lower() != "energia":
		return {"sucesso": false, "motivo": "A carta selecionada não é uma Energia."}

	if GameState.energia_anexada_neste_turno:
		return {"sucesso": false, "motivo": "Você já anexou uma energia neste turno."}

	var ativo := GameState.obter_ativo(player.id)
	var banco := GameState.obter_banco(player.id)

	if animal != ativo and not banco.has(animal):
		return {"sucesso": false, "motivo": "O animal alvo não pertence ao seu campo."}

	return {"sucesso": true, "motivo": "Energia anexada com sucesso."}


# ==================================================
# COMIDA
# ==================================================

static func validar_distribuicao_comida(player: PlayerState, animal: AnimalInstance, quantidade: int) -> Dictionary:
	if player == null or animal == null:
		return {"sucesso": false, "motivo": "Parâmetros inválidos."}

	if quantidade <= 0:
		return {"sucesso": false, "motivo": "Quantidade de comida deve ser maior que zero."}

	if quantidade > player.comida_disponivel:
		return {"sucesso": false, "motivo": "Comida insuficiente na reserva do jogador."}

	var ativo := GameState.obter_ativo(player.id)
	var banco := GameState.obter_banco(player.id)

	if animal != ativo and not banco.has(animal):
		return {"sucesso": false, "motivo": "O animal alvo não pertence ao seu campo."}

	return {"sucesso": true, "motivo": "Alimentação autorizada."}


# ==================================================
# CATACLISMOS
# ==================================================

static func validate_cataclysm(player: PlayerState, card: EffectResource) -> Dictionary:
	print("\n🔍 [RuleValidator] Validando jogada de Cataclismo '%s'..." % [card.name if card else "Nula"])

	if player == null or card == null:
		return {"sucesso": false, "motivo": "Parâmetros inválidos para jogar Cataclismo."}

	if card.super_type.to_lower() != "cataclismo":
		return {"sucesso": false, "motivo": "A carta informada não é do tipo Cataclismo."}

	if not GameState.partida_ativa:
		return {"sucesso": false, "motivo": "A partida não está ativa."}

	if GameState.jogador_ativo != player.id:
		return {"sucesso": false, "motivo": "Não é o seu turno."}

	if GameState.fase_atual != GameState.Fase.PRINCIPAL:
		return {"sucesso": false, "motivo": "Cataclismos só podem ser jogados na Fase Principal."}

	if not player.mao.has(card):
		return {"sucesso": false, "motivo": "A carta não está na mão do jogador."}

	if GameState.cataclismo_jogado_neste_turno:
		return {"sucesso": false, "motivo": "Você já jogou um Cataclismo neste turno."}

	print("✅ [RuleValidator] Cataclismo AUTORIZADO!")
	return {"sucesso": true, "motivo": "Cataclismo autorizado."}


# ==================================================
# CONDIÇÕES ESPECIAIS E STATUS
# ==================================================

static func validate_status_application(target: AnimalInstance, _status: ConditionSystem.Tipo) -> bool:
	if target == null or target.current_hp <= 0:
		return false

	if ConditionSystem.possui_condicao(target, ConditionSystem.Tipo.PROTEGIDO):
		print("🛡️ [RuleValidator] Status negado: '%s' está Protegido." % target.card.name)
		return false

	return true


static func validate_status_removal(target: AnimalInstance) -> bool:
	if target == null:
		return false
	return ConditionSystem.obter_condicao(target) != ConditionSystem.Tipo.NENHUMA


static func validate_sleep(animal: AnimalInstance) -> bool:
	return ConditionSystem.possui_condicao(animal, ConditionSystem.Tipo.ADORMECIDO)


static func validate_paralysis(animal: AnimalInstance) -> bool:
	return ConditionSystem.possui_condicao(animal, ConditionSystem.Tipo.PARALISADO)


static func validate_poison(animal: AnimalInstance) -> bool:
	return ConditionSystem.possui_condicao(animal, ConditionSystem.Tipo.ENVENENADO)


static func validate_bleeding(animal: AnimalInstance) -> bool:
	return ConditionSystem.possui_condicao(animal, ConditionSystem.Tipo.SANGRANDO)


# ==================================================
# RECUO
# ==================================================

static func validar_recuo(player: PlayerState, energias_descarte: Array) -> Dictionary:
	if player == null:
		return {"sucesso": false, "motivo": "Jogador inválido."}

	var ativo: AnimalInstance = GameState.obter_ativo(player.id)
	if ativo == null:
		return {"sucesso": false, "motivo": "Você não possui um animal ativo."}

	if GameState.recuo_realizado_neste_turno:
		return {"sucesso": false, "motivo": "Você já recuou um animal neste turno."}

	if GameState.obter_banco(player.id).is_empty():
		return {"sucesso": false, "motivo": "Você precisa de pelo menos 1 animal no banco para recuar."}

	if not ConditionSystem.pode_tentar_acao(ativo, "recuar"):
		return {"sucesso": false, "motivo": "O animal não pode recuar devido ao seu status atual."}

	var custo: int = ativo.card.cost_retreat
	if energias_descarte.size() < custo:
		return {"sucesso": false, "motivo": "Energias suficientes não foram selecionadas para pagar o custo de recuo (%d)." % custo}

	for energia in energias_descarte:
		if not ativo.attached_energies.has(energia):
			return {"sucesso": false, "motivo": "Uma das energias selecionadas não está anexada ao animal."}

	return {"sucesso": true, "motivo": "Recuo autorizado."}


# ==================================================
# ATAQUE & COMBATE
# ==================================================

static func validar_atacar(jogador_id: int) -> Dictionary:
	print("\n🔍 [RuleValidator] Validando ataque para Jogador %d..." % jogador_id)

	if not GameState.partida_ativa:
		return {"sucesso": false, "motivo": "A partida não está ativa."}

	if GameState.jogador_ativo != jogador_id:
		return {"sucesso": false, "motivo": "Não é o seu turno de jogar."}

	if GameState.fase_atual != GameState.Fase.PRINCIPAL:
		return {"sucesso": false, "motivo": "Ataques só podem ser realizados durante a Fase Principal."}

	if GameState.turno_atual <= 1:
		return {"sucesso": false, "motivo": "Não é permitido atacar no Turno 1 do jogo."}

	var atacante: AnimalInstance = GameState.obter_ativo(jogador_id)
	if atacante == null:
		return {"sucesso": false, "motivo": "Você não possui um animal ativo."}

	if atacante.current_hp <= 0:
		return {"sucesso": false, "motivo": "%s está nocauteado." % atacante.card.name}

	if atacante.ja_atacou_este_turno:
		return {"sucesso": false, "motivo": "%s já realizou um ataque neste turno." % atacante.card.name}

	if not ConditionSystem.pode_tentar_acao(atacante, "atacar"):
		var status_nome: String = ConditionSystem.Tipo.keys()[ConditionSystem.obter_condicao(atacante)]
		return {"sucesso": false, "motivo": "%s está impedido de atacar devido ao status: %s." % [atacante.card.name, status_nome]}

	if not atacante.pode_usar_ataque(atacante.card):
		return {"sucesso": false, "motivo": "%s não possui as energias necessárias para este ataque." % atacante.card.name}

	var id_oponente: int = 1 if jogador_id == 0 else 0
	var defensor: AnimalInstance = GameState.obter_ativo(id_oponente)

	if defensor == null or defensor.current_hp <= 0:
		return {"sucesso": false, "motivo": "O oponente não possui um animal ativo válido para ser atacado."}

	print("✅ [RuleValidator] Ataque AUTORIZADO! %s -> %s" % [atacante.card.name, defensor.card.name])
	return {"sucesso": true, "motivo": "Ataque autorizado."}


## Wrapper booleano mantido para compatibilidade
static func validate_attack(atacante: AnimalInstance, _ataque: CardResource) -> bool:
	if atacante == null:
		return false
	var jogador_id: int = 0 if GameState.obter_ativo(0) == atacante else 1
	return validar_atacar(jogador_id)["sucesso"]

# ==================================================
# REGRAS DE EFEITOS DATA-DRIVEN & SELEÇÃO
# ==================================================

## ----------------------------------------------------
## BUSCA NO DECK (MÃO OU CAMPO)
## Valida se o baralho possui pelo menos uma carta que
## atenda aos critérios passados pela mecânica.
## ----------------------------------------------------
static func validar_busca_deck(
	player: PlayerState,
	filtro_tipo: String = "QUALQUER",
	filtro_cor: String = "QUALQUER",
	filtro_estagio: String = "QUALQUER",
	filtro_nome: String = ""
) -> Dictionary:
	if player == null:
		return {"sucesso": false, "motivo": "Jogador inválido."}

	if player.deck.is_empty():
		return {"sucesso": false, "motivo": "O baralho do jogador está vazio."}

	# Varre o deck verificando se existe ao menos 1 carta elegível
	for carta in player.deck:
		if carta == null:
			continue

		# Filtro de Super Tipo / Tipo (ex: "ENERGIA", "ANIMAL")
		if filtro_tipo != "QUALQUER" and carta.super_type.to_upper() != filtro_tipo.to_upper():
			continue

		# Filtro de Cor / Elemento (ex: "VERMELHO", "AZUL")
		if filtro_cor != "QUALQUER":
			var cor_carta: String = carta.color.to_upper() if "color" in carta else ""
			if cor_carta != filtro_cor.to_upper():
				continue

		# Filtro de Estágio de Evolução (ex: "FILHOTE", "ADULTO")
		if filtro_estagio != "QUALQUER":
			var estagio_carta: String = carta.stage.to_upper() if "stage" in carta else ""
			if estagio_carta != filtro_estagio.to_upper():
				continue

		# Filtro por Nome Específico da Espécie (ex: "Velociraptor", "Nodossauro")
		if not filtro_nome.is_empty():
			if not filtro_nome.to_upper() in carta.name.to_upper():
				continue

		# Se encontrou ao menos uma carta compatível, a busca é autorizada
		return {"sucesso": true, "motivo": "Carta elegível encontrada no deck."}

	return {"sucesso": false, "motivo": "Nenhuma carta compatível com os filtros foi encontrada no deck."}


## ----------------------------------------------------
## ENERGIZAÇÃO EXTRA VIA EFEITO
## Valida a anexação de energia vinda de efeitos de ataque
## ou cataclismos (ignora a trava de 1 energia por turno da mão).
## ----------------------------------------------------
static func validar_energizar_efeito(
	player: PlayerState,
	animal_alvo: AnimalInstance,
	energia_carta: EffectResource
) -> Dictionary:
	if player == null or animal_alvo == null or energia_carta == null:
		return {"sucesso": false, "motivo": "Parâmetros inválidos para energização por efeito."}

	if energia_carta.super_type.to_upper() != "ENERGIA":
		return {"sucesso": false, "motivo": "A carta informada não é uma Energia."}

	var ativo := GameState.obter_ativo(player.id)
	var banco := GameState.obter_banco(player.id)

	if animal_alvo != ativo and not banco.has(animal_alvo):
		return {"sucesso": false, "motivo": "O animal alvo não pertence ao seu campo."}

	return {"sucesso": true, "motivo": "Energização via efeito autorizada."}


## ----------------------------------------------------
## TROCA FORÇADA / PUXAR BANCO DO OPONENTE
## Valida se o oponente possui alvos elegíveis no banco
## para serem puxados para o campo ativo.
## ----------------------------------------------------
static func validar_trocar_ativo_oponente(id_oponente: int) -> Dictionary:
	var banco_oponente: Array = GameState.obter_banco(id_oponente)

	if banco_oponente.is_empty():
		return {"sucesso": false, "motivo": "O banco do oponente está vazio."}

	# Verifica se há pelo menos um animal no banco que não esteja totalmente protegido contra efeitos
	for animal in banco_oponente:
		if animal != null and not validate_status_application(animal, ConditionSystem.Tipo.PROTEGIDO):
			return {"sucesso": true, "motivo": "Troca forçada autorizada."}

	return {"sucesso": true, "motivo": "Troca forçada autorizada."}


## ----------------------------------------------------
## DESCARTE DE RECURSOS DE UM ANIMAL
## Valida se um animal possui a quantidade e o tipo de
## energia necessários para serem descartados por um efeito.
## ----------------------------------------------------
static func validar_descarte_recurso_animal(
	animal: AnimalInstance,
	quantidade: int,
	filtro_cor: String = "QUALQUER"
) -> Dictionary:
	if animal == null:
		return {"sucesso": false, "motivo": "Animal alvo é nulo."}

	if animal.attached_energies.is_empty():
		return {"sucesso": false, "motivo": "O animal não possui energias anexadas."}

	if filtro_cor == "QUALQUER":
		if animal.attached_energies.size() < quantidade:
			return {"sucesso": false, "motivo": "O animal possui menos energias do que a quantidade exigida para descarte."}
		return {"sucesso": true, "motivo": "Descarte de energia autorizado."}

	# Validação de energia com cor/elemento específico
	var qtd_encontrada: int = 0
	for energia in animal.attached_energies:
		if energia != null and "color" in energia:
			if energia.color.to_upper() == filtro_cor.to_upper():
				qtd_encontrada += 1

	if qtd_encontrada < quantidade:
		return {"sucesso": false, "motivo": "O animal não possui energias suficientes da cor '%s' para descartar." % filtro_cor}

	return {"sucesso": true, "motivo": "Descarte de energia específica autorizado."}


## ----------------------------------------------------
## CONTAGEM DE PRESENÇA EM CAMPO
## Função utilitária de consulta rápida para bônus de
## dano baseados em espécies ou estágios específicos em jogo.
## ----------------------------------------------------
static func contar_presenca_campo(
	id_jogador: int,
	filtro_nome: String = "",
	filtro_estagio: String = "QUALQUER",
	apenas_banco: bool = false
) -> int:
	var total: int = 0
	var animais_para_checar: Array = []

	if apenas_banco:
		animais_para_checar = GameState.obter_banco(id_jogador).duplicate()
	else:
		animais_para_checar = GameState.obter_animais_em_campo(id_jogador)

	for inst in animais_para_checar:
		if inst == null or inst.card == null:
			continue

		if not filtro_nome.is_empty() and not filtro_nome.to_upper() in inst.card.name.to_upper():
			continue

		if filtro_estagio != "QUALQUER" and inst.card.stage.to_upper() != filtro_estagio.to_upper():
			continue

		total += 1

	return total

# ==================================================
# REGRAS DE COMBATE & DANO
# ==================================================

static func validate_weakness(atacante: AnimalInstance, defensor: AnimalInstance) -> bool:
	if atacante == null or defensor == null:
		return false
	return defensor.card.weakness != "" and defensor.card.weakness == atacante.card.color


static func validate_resistance(atacante: AnimalInstance, defensor: AnimalInstance) -> bool:
	if atacante == null or defensor == null:
		return false
	return defensor.card.resistance != "" and defensor.card.resistance == atacante.card.color


static func validate_knockout(animal: AnimalInstance) -> bool:
	if animal == null:
		return false
	return animal.current_hp <= 0

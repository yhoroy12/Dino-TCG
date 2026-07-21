class_name ConditionSystem

# ==================================================
# CONDITION SYSTEM (Estático Puro)
# Gerencia status especiais e dano passivo. Não emite sinais.
# ==================================================

enum Tipo {
	NENHUMA,
	ADORMECIDO,
	PARALISADO,
	ENVENENADO,
	SANGRANDO,
	CONDENADO
}

# ==================================================
# GERENCIAMENTO DE STATUS
# ==================================================

static func aplicar_condicao(
	instancia: AnimalInstance,
	tipo_condicao: Tipo
) -> void:

	if instancia == null:
		return

	instancia.conditions.clear()

	if tipo_condicao == Tipo.NENHUMA:
		return

	var dados_condicao := {
		"tipo": tipo_condicao,
		"turnos": 0,
		"turnos_sem_dano_externo": 0,
		"turnos_condenado": 0
	}

	instancia.conditions.append(dados_condicao)


static func limpar_todas_as_condicoes(
	instancia: AnimalInstance
) -> void:

	if instancia == null or instancia.conditions.is_empty():
		return

	instancia.conditions.clear()


static func possui_condicao(
	instancia: AnimalInstance,
	tipo: Tipo
) -> bool:

	if instancia == null or instancia.conditions.is_empty():
		return false

	return instancia.conditions[0]["tipo"] == tipo


static func obter_condicao(
	instancia: AnimalInstance
) -> Tipo:

	if instancia == null or instancia.conditions.is_empty():
		return Tipo.NENHUMA

	return instancia.conditions[0]["tipo"]


# ==================================================
# DANO PASSIVO E PROCESSAMENTO
# ==================================================

static func processar_fim_de_turno(
	instancia: AnimalInstance
) -> void:

	if instancia == null or instancia.conditions.is_empty():
		return

	var cond = instancia.conditions[0]

	# Aplica dano passivo diretamente na instância
	var dano_passivo := _calcular_dano_por_turno(cond["tipo"])
	if dano_passivo > 0:
		instancia.current_hp = max(0, instancia.current_hp - dano_passivo)

	# Resolução das condições
	match cond["tipo"]:

		Tipo.ADORMECIDO:
			if randf() >= 0.5:
				limpar_todas_as_condicoes(instancia)

		Tipo.PARALISADO:
			cond["turnos"] += 1
			if cond["turnos"] >= 3:
				limpar_todas_as_condicoes(instancia)

		Tipo.SANGRANDO:
			if cond["turnos_sem_dano_externo"] >= 2:
				limpar_todas_as_condicoes(instancia)

		Tipo.CONDENADO:
			cond["turnos_condenado"] += 1
			if cond["turnos_condenado"] >= 3:
				instancia.current_hp = 0


static func _calcular_dano_por_turno(tipo: Tipo) -> int:
	match tipo:
		Tipo.ENVENENADO:
			return 10
		Tipo.SANGRANDO:
			return 20
	return 0


# ==================================================
# RESTRIÇÕES DE AÇÃO
# ==================================================

static func pode_tentar_acao(
	instancia: AnimalInstance,
	acao: String
) -> bool:

	if instancia == null or instancia.conditions.is_empty():
		return true

	var cond = instancia.conditions[0]

	if cond["tipo"] == Tipo.ADORMECIDO:
		if acao == "atacar" or acao == "recuar":
			return false

	return true


static func rodar_moeda_paralisia(
	instancia: AnimalInstance
) -> bool:

	if instancia == null or instancia.conditions.is_empty():
		return true

	var cond = instancia.conditions[0]

	if cond["tipo"] == Tipo.PARALISADO:
		return randf() >= 0.5

	return true


# ==================================================
# CONTADORES ESPECIAIS
# ==================================================

static func notificar_turno_sem_dano_sangramento(
	instancia: AnimalInstance
) -> void:

	if instancia == null or instancia.conditions.is_empty():
		return

	var cond = instancia.conditions[0]

	if cond["tipo"] == Tipo.SANGRANDO:
		cond["turnos_sem_dano_externo"] += 1

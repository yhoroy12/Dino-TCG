class_name ConditionSystem

# ==================================================
# CONDITION SYSTEM (Estático Puro)
# Gerencia status especiais, restrições e dano passivo.
# ==================================================

enum Tipo {
	NENHUMA,
	ADORMECIDO,
	PARALISADO,
	ENVENENADO,
	SANGRANDO,
	CONDENADO,
	PROTEGIDO,
	IMUNE,
	PRESO,
	RECARREGANDO
}

# Helper interno para formatar o nome da condição nos logs
static func _obter_nome_condicao(tipo: Tipo) -> String:
	match tipo:
		Tipo.ADORMECIDO:   return "Adormecido"
		Tipo.PARALISADO:   return "Paralisado"
		Tipo.ENVENENADO:   return "Envenenado"
		Tipo.SANGRANDO:    return "Sangrando"
		Tipo.CONDENADO:    return "Condenado"
		Tipo.PROTEGIDO:    return "Protegido"
		Tipo.IMUNE:        return "Imune"
		Tipo.PRESO:        return "Preso"
		Tipo.RECARREGANDO: return "Recarregando"
		_:                 return "Nenhuma"


# ==================================================
# GERENCIAMENTO DE STATUS
# ==================================================

static func aplicar_condicao(
	instancia: AnimalInstance,
	tipo_condicao: Tipo
) -> void:

	if instancia == null:
		return

	var nome_dino: String = instancia.card.name if instancia.card else "Animal"

	if tipo_condicao == Tipo.NENHUMA:
		limpar_todas_as_condicoes(instancia)
		return

	# Alvo com status IMUNE rejeita novos status negativos
	if possui_condicao(instancia, Tipo.IMUNE) and tipo_condicao != Tipo.IMUNE:
		print("🛡️ [ConditionSystem] '%s' está IMUNE e não recebeu o status '%s'." % [nome_dino, _obter_nome_condicao(tipo_condicao)])
		return

	instancia.conditions.clear()

	var dados_condicao := {
		"tipo": tipo_condicao,
		"turnos": 0,
		"turnos_sem_dano_externo": 0,
		"turnos_condenado": 0
	}

	instancia.conditions.append(dados_condicao)
	print("🧪 [ConditionSystem] Status '%s' aplicado com sucesso a '%s'." % [_obter_nome_condicao(tipo_condicao), nome_dino])


static func limpar_todas_as_condicoes(
	instancia: AnimalInstance
) -> void:

	if instancia == null or instancia.conditions.is_empty():
		return

	var nome_dino: String = instancia.card.name if instancia.card else "Animal"
	var tipo_atual: Tipo = instancia.conditions[0]["tipo"]

	instancia.conditions.clear()
	print("🧪 [ConditionSystem] Status '%s' removido de '%s'." % [_obter_nome_condicao(tipo_atual), nome_dino])


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
# DANO PASSIVO E PROCESSAMENTO DE TURNO
# ==================================================

static func processar_fim_de_turno(
	instancia: AnimalInstance
) -> void:

	if instancia == null or instancia.conditions.is_empty():
		return

	var cond = instancia.conditions[0]
	var nome_dino: String = instancia.card.name if instancia.card else "Animal"
	var nome_status: String = _obter_nome_condicao(cond["tipo"] as int)

	# 1. Aplica dano passivo (se houver)
	var dano_passivo := _calcular_dano_por_turno(cond["tipo"])
	if dano_passivo > 0:
		instancia.current_hp = max(0, instancia.current_hp - dano_passivo)
		print("🧪 [ConditionSystem] '%s' sofreu %d de dano passivo por '%s'. HP restante: %d" % [
			nome_dino, dano_passivo, nome_status, instancia.current_hp
		])

	# 2. Resolução e contagem de turnos
	match cond["tipo"]:

		Tipo.ADORMECIDO:
			cond["turnos"] += 1
			print("😴 [ConditionSystem] '%s' dormiu por %d/2 turno(s)." % [nome_dino, cond["turnos"]])
			if cond["turnos"] >= 2:
				print("⏰ [ConditionSystem] '%s' descansou o suficiente e acordou!" % nome_dino)
				limpar_todas_as_condicoes(instancia)

		Tipo.PARALISADO:
			cond["turnos"] += 1
			print("⏱️ [ConditionSystem] '%s' paralisado há %d/3 turno(s)." % [nome_dino, cond["turnos"]])
			if cond["turnos"] >= 3:
				print("🧪 [ConditionSystem] Paralisia de '%s' expirou." % nome_dino)
				limpar_todas_as_condicoes(instancia)

		Tipo.SANGRANDO:
			print("🩸 [ConditionSystem] '%s' sangrando (%d/2 turnos sem dano externo)." % [nome_dino, cond["turnos_sem_dano_externo"]])
			if cond["turnos_sem_dano_externo"] >= 2:
				print("🧪 [ConditionSystem] Sangramento de '%s' estancou." % nome_dino)
				limpar_todas_as_condicoes(instancia)

		Tipo.CONDENADO:
			cond["turnos_condenado"] += 1
			print("💀 [ConditionSystem] '%s' condenado (%d/3 turnos)." % [nome_dino, cond["turnos_condenado"]])
			if cond["turnos_condenado"] >= 3:
				print("💀 [ConditionSystem] Efeito CONDENADO consumado: HP de '%s' foi zerado!" % nome_dino)
				instancia.current_hp = 0

		Tipo.PROTEGIDO, Tipo.IMUNE, Tipo.PRESO, Tipo.RECARREGANDO:
			cond["turnos"] += 1
			if cond["turnos"] >= 1:
				print("🧪 [ConditionSystem] Status '%s' de '%s' expirou no fim do turno." % [nome_status, nome_dino])
				limpar_todas_as_condicoes(instancia)


static func _calcular_dano_por_turno(tipo: Tipo) -> int:
	match tipo:
		Tipo.ENVENENADO:
			return 10
		Tipo.SANGRANDO:
			return 20
	return 0


# ==================================================
# EVENTOS E GATILHOS EXTERNOS
# ==================================================

## Notifica o sistema de que o animal recebeu dano direto de um ataque
static func notificar_dano_recebido(instancia: AnimalInstance) -> void:
	if instancia == null or instancia.conditions.is_empty():
		return

	var cond = instancia.conditions[0]
	var nome_dino: String = instancia.card.name if instancia.card else "Animal"

	# Regra do ADORMECIDO: acorda imediatamente ao tomar dano
	if cond["tipo"] == Tipo.ADORMECIDO:
		print("⚡ [ConditionSystem] '%s' recebeu dano e acordou do sono!" % nome_dino)
		limpar_todas_as_condicoes(instancia)

	# Reseta a contagem de tempo sem dano para o SANGRANDO
	if cond["tipo"] == Tipo.SANGRANDO:
		cond["turnos_sem_dano_externo"] = 0


static func notificar_turno_sem_dano_sangramento(instancia: AnimalInstance) -> void:
	if instancia == null or instancia.conditions.is_empty():
		return

	var cond = instancia.conditions[0]
	var nome_dino: String = instancia.card.name if instancia.card else "Animal"

	if cond["tipo"] == Tipo.SANGRANDO:
		cond["turnos_sem_dano_externo"] += 1
		print("🩸 [ConditionSystem] '%s' passou turno sem dano. Contador sangramento: %d/2." % [
			nome_dino, cond["turnos_sem_dano_externo"]
		])


# ==================================================
# RESTRIÇÕES DE AÇÃO E DANO
# ==================================================

static func pode_tentar_acao(
	instancia: AnimalInstance,
	acao: String
) -> bool:

	if instancia == null or instancia.conditions.is_empty():
		return true

	var cond = instancia.conditions[0]
	var nome_dino: String = instancia.card.name if instancia.card else "Animal"

	match cond["tipo"]:
		Tipo.ADORMECIDO:
			if acao in ["atacar", "recuar"]:
				print("⛔ [ConditionSystem] Ação '%s' BLOQUEADA para '%s' (Motivo: Adormecido)." % [acao, nome_dino])
				return false

		Tipo.PRESO:
			if acao == "recuar":
				print("⛔ [ConditionSystem] Ação 'recuar' BLOQUEADA para '%s' (Motivo: Preso)." % nome_dino)
				return false

		Tipo.RECARREGANDO:
			if acao == "atacar":
				print("⛔ [ConditionSystem] Ação 'atacar' BLOQUEADA para '%s' (Motivo: Recarregando)." % nome_dino)
				return false

	return true


static func pode_receber_dano_direto(instancia: AnimalInstance) -> bool:
	if instancia == null or instancia.conditions.is_empty():
		return true

	if possui_condicao(instancia, Tipo.PROTEGIDO) or possui_condicao(instancia, Tipo.IMUNE):
		var nome_dino: String = instancia.card.name if instancia.card else "Animal"
		print("🛡️ [ConditionSystem] '%s' bloqueou o dano por estar PROTEGIDO/IMUNE!" % nome_dino)
		return false

	return true


static func rodar_moeda_paralisia(
	instancia: AnimalInstance
) -> bool:

	if instancia == null or instancia.conditions.is_empty():
		return true

	var cond = instancia.conditions[0]
	var nome_dino: String = instancia.card.name if instancia.card else "Animal"

	if cond["tipo"] == Tipo.PARALISADO:
		var sucesso := randf() >= 0.5
		print("🪙 [ConditionSystem] Moeda de Paralisia para '%s': %s" % [
			nome_dino, 
			"CARA (Ação Permitida)" if sucesso else "COROA (Ação Bloqueada)"
		])
		return sucesso

	return true

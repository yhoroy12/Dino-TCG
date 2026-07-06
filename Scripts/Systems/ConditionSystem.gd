# ==================================================
# Nome: ConditionSystem
# Categoria: Systems
# Responsável pelas condições especiais.
#
# Deve controlar:
# - Veneno
# - Sangramento
# - Paralisado
# - Sono
# - Outros status negativos
#
# Regras Oficiais do Rulebook.
# ==================================================

class_name ConditionSystem

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

## Aplica uma nova condição.
## Como as condições não acumulam, a nova substitui a anterior.
static func aplicar_condicao(
	instancia: AnimalInstance,
	tipo_condicao: Tipo
) -> void:

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


## Remove qualquer condição especial.
static func limpar_todas_as_condicoes(
	instancia: AnimalInstance
) -> void:

	instancia.conditions.clear()


## Verifica se o animal possui uma condição específica.
static func possui_condicao(
	instancia: AnimalInstance,
	tipo: Tipo
) -> bool:

	if instancia.conditions.is_empty():
		return false

	return instancia.conditions[0]["tipo"] == tipo


## Retorna a condição atual.
static func obter_condicao(
	instancia: AnimalInstance
) -> Tipo:

	if instancia.conditions.is_empty():
		return Tipo.NENHUMA

	return instancia.conditions[0]["tipo"]


# ==================================================
# DANO PASSIVO
# ==================================================

## Calcula dano causado por condições especiais.
static func calcular_dano_por_turno(
	instancia: AnimalInstance
) -> int:

	if instancia.conditions.is_empty():
		return 0

	var cond = instancia.conditions[0]

	match cond["tipo"]:
		Tipo.ENVENENADO:
			return 10

		Tipo.SANGRANDO:
			return 20

	return 0


# ==================================================
# PROCESSAMENTO DE FIM DE TURNO
# ==================================================

static func processar_fim_de_turno(
	instancia: AnimalInstance
) -> void:

	if instancia.conditions.is_empty():
		return

	var cond = instancia.conditions[0]

	match cond["tipo"]:

		Tipo.ADORMECIDO:

			# Cara = cura
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

			if cond["turnos_condenado"] >= 3:

				# O KnockoutSystem detectará o KO.
				instancia.current_hp = 0


# ==================================================
# RESTRIÇÕES DE AÇÃO
# ==================================================

## Verifica se o animal pode tentar executar uma ação.
static func pode_tentar_acao(
	instancia: AnimalInstance,
	acao: String
) -> bool:

	if instancia.conditions.is_empty():
		return true

	var cond = instancia.conditions[0]

	if cond["tipo"] == Tipo.ADORMECIDO:

		if acao == "atacar":
			return false

		if acao == "recuar":
			return false

	return true


## Regra da Paralisia.
## Cara = ação executada.
## Coroa = ação falha.
static func rodar_moeda_paralisia(
	instancia: AnimalInstance
) -> bool:

	if instancia.conditions.is_empty():
		return true

	var cond = instancia.conditions[0]

	if cond["tipo"] == Tipo.PARALISADO:

		if randf() >= 0.5:
			return true

		return false

	return true


# ==================================================
# CONTADORES ESPECIAIS
# ==================================================

## Chamar quando o turno terminar sem o animal
## receber dano de ataque.
static func notificar_turno_sem_dano_sangramento(
	instancia: AnimalInstance
) -> void:

	if instancia.conditions.is_empty():
		return

	var cond = instancia.conditions[0]

	if cond["tipo"] == Tipo.SANGRANDO:
		cond["turnos_sem_dano_externo"] += 1


## Chamar ao final de cada turno em que o animal
## permanecer ativo enquanto estiver Condenado.
static func notificar_turno_condenado(
	instancia: AnimalInstance
) -> void:

	if instancia.conditions.is_empty():
		return

	var cond = instancia.conditions[0]

	if cond["tipo"] == Tipo.CONDENADO:
		cond["turnos_condenado"] += 1

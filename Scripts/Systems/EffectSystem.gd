# ==================================================
# Nome: EffectSystem
# Categoria: Systems
#
# Responsável por ARMAZENAR, CONSULTAR e EXPIRAR efeitos
# temporários genéricos anexados a um AnimalInstance
# (campo AnimalInstance.temporary_effects).
#
# O QUE ESTE SISTEMA NÃO FAZ:
# - Não decide O QUE cada carta faz. Interpretar Vestígio,
#   Território, Cataclismo ou Habilidade e decidir QUANDO
#   chamar aplicar_efeito() é responsabilidade do BattleManager.
# - Não calcula dano. CombatSystem apenas CONSULTA valores
#   por aqui.
# - Não acessa GameState, nós de cena, UI, sinais ou SceneTree.
#
# Este é o ÚNICO sistema que conhece o formato interno do
# Dictionary de efeito. Nenhum outro sistema deve montar ou
# ler esse Dictionary manualmente — sempre passar pelas
# funções públicas abaixo. Isso garante que, se o formato
# mudar no futuro, só este arquivo precisa ser tocado.
# ==================================================

class_name EffectSystem


# --------------------------------------------------
# TAGS PADRÃO DE EFEITO
# Fonte única da verdade dos tipos de efeito conhecidos por
# CombatSystem e outros consumidores. Novas tags podem ser
# adicionadas livremente sem quebrar nada, pois o sistema
# trabalha com String, não com enum fechado.
# --------------------------------------------------

const TAG_BONUS_DANO: String = "bonus_dano"
const TAG_REDUCAO_DANO: String = "reducao_dano"
const TAG_MULTIPLICADOR_DANO: String = "multiplicador_dano"


# --------------------------------------------------
# ESCOPO DE DURAÇÃO
# Define QUANDO um efeito perde uma "carga" de duração.
# --------------------------------------------------

enum Escopo {
	TURNO_ATUAL,     # Expira ao final do turno em que foi criado, seja de quem for.
	TURNOS_DO_DONO,  # Só decrementa quando termina o turno do DONO do animal-alvo.
	PERMANENTE       # Nunca decrementa sozinho; sai só via remoção explícita.
}


# ==================================================
# APLICAÇÃO DE EFEITOS
# ==================================================

## Anexa um novo efeito temporário a um animal.
##
## origem_id identifica quem criou o efeito (id da carta de
## Vestígio/Território/Cataclismo/Habilidade que o gerou).
## Isso permite remover o efeito em cascata caso a origem
## saia de campo, sem o EffectSystem precisar saber o motivo.
static func aplicar_efeito(
	alvo: AnimalInstance,
	tipo: String,
	valor: float,
	duracao_turnos: int,
	escopo_duracao: Escopo,
	origem_id: String = ""
) -> void:

	if alvo == null:
		return

	var efeito := {
		"tipo": tipo,
		"valor": valor,
		"duracao_turnos": duracao_turnos,
		"escopo_duracao": escopo_duracao,
		"origem_id": origem_id
	}

	alvo.temporary_effects.append(efeito)


# ==================================================
# REMOÇÃO DE EFEITOS
# ==================================================

## Remove todos os efeitos criados por uma origem específica.
## Deve ser chamado por quem gerencia zonas (BattleManager /
## KnockoutSystem / etc.) quando a carta de origem sai de
## campo — ex: Vestígio destruído, Território substituído.
static func remover_efeitos_por_origem(
	alvo: AnimalInstance,
	origem_id: String
) -> void:

	if alvo == null or origem_id == "":
		return

	var restantes: Array = []

	for efeito in alvo.temporary_effects:
		if efeito.get("origem_id", "") != origem_id:
			restantes.append(efeito)

	alvo.temporary_effects = restantes


## Remove todos os efeitos temporários de um animal, sem
## distinção de tipo ou origem. Útil em casos como troca de
## dono, reset de estado, ou regras especiais de "purificar".
static func remover_todos_os_efeitos(
	alvo: AnimalInstance
) -> void:

	if alvo == null:
		return

	alvo.temporary_effects.clear()


# ==================================================
# CONSULTA DE EFEITOS
# Único ponto de leitura do formato do Dictionary de efeito.
# CombatSystem e qualquer sistema futuro devem consultar por
# aqui, nunca ler AnimalInstance.temporary_effects diretamente.
# ==================================================

## Soma os valores de todos os efeitos de um tipo (tag).
## Usado para bônus/reduções fixos (ex: +30 de dano).
static func obter_soma(
	alvo: AnimalInstance,
	tipo: String
) -> float:

	if alvo == null:
		return 0.0

	var total: float = 0.0

	for efeito in alvo.temporary_effects:
		if efeito.get("tipo", "") == tipo:
			total += float(efeito.get("valor", 0.0))

	return total


## Multiplica os valores de todos os efeitos de um tipo (tag).
## Usado para multiplicadores de dano (ex: "próximo ataque
## causa 150%"). Retorna 1.0 quando não há efeitos desse tipo.
static func obter_multiplicador(
	alvo: AnimalInstance,
	tipo: String
) -> float:

	if alvo == null:
		return 1.0

	var multiplicador: float = 1.0

	for efeito in alvo.temporary_effects:
		if efeito.get("tipo", "") == tipo:
			multiplicador *= float(efeito.get("valor", 1.0))

	return multiplicador


## Verifica se o animal possui ao menos um efeito de um tipo.
static func possui_efeito(
	alvo: AnimalInstance,
	tipo: String
) -> bool:

	if alvo == null:
		return false

	for efeito in alvo.temporary_effects:
		if efeito.get("tipo", "") == tipo:
			return true

	return false


# ==================================================
# PROCESSAMENTO DE FIM DE TURNO
# Deve ser chamado pelo TurnManager para CADA animal em
# campo (de ambos os jogadores), uma vez a cada fim de turno.
# ==================================================

## Decrementa a duração dos efeitos de um animal e remove os
## que expiraram.
##
## era_turno_do_dono: true quando o turno que está terminando
## é o do JOGADOR DONO deste animal-alvo. Quem decide esse
## valor é o TurnManager (ele sabe de quem é o turno e de quem
## é cada animal) — o EffectSystem não conhece jogadores.
static func processar_fim_de_turno(
	alvo: AnimalInstance,
	era_turno_do_dono: bool
) -> void:

	if alvo == null or alvo.temporary_effects.is_empty():
		return

	var restantes: Array = []

	for efeito in alvo.temporary_effects:
		var escopo: int = efeito.get("escopo_duracao", Escopo.TURNO_ATUAL)

		# Efeitos permanentes nunca decrementam automaticamente.
		if escopo == Escopo.PERMANENTE:
			restantes.append(efeito)
			continue

		var deve_decrementar := false

		if escopo == Escopo.TURNO_ATUAL:
			deve_decrementar = true
		elif escopo == Escopo.TURNOS_DO_DONO:
			deve_decrementar = era_turno_do_dono

		if deve_decrementar:
			efeito["duracao_turnos"] -= 1

		if efeito["duracao_turnos"] > 0:
			restantes.append(efeito)

	alvo.temporary_effects = restantes

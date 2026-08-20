class_name DamageSystem

# ==================================================
# DAMAGE SYSTEM
# Responsável exclusivamente por APLICAR um valor de dano já
# calculado ao HP de um animal.
# ==================================================


## Aplica dano ao HP atual do alvo. Nunca deixa o valor negativo.
static func aplicar_dano(alvo: AnimalInstance, quantidade: int) -> void:
	if alvo == null or quantidade <= 0:
		return

	alvo.current_hp = max(0, alvo.current_hp - quantidade)

	# ⚡ Notifica o ConditionSystem que o animal sofreu dano direto!
	# (Acorda o animal se estiver ADORMECIDO e reseta o SANGRANDO)
	ConditionSystem.notificar_dano_recebido(alvo)


## Cura HP do alvo, sem nunca ultrapassar o HP máximo da carta atual.
static func curar(alvo: AnimalInstance, quantidade: int) -> void:
	if alvo == null or quantidade <= 0:
		return

	alvo.current_hp = min(alvo.card.hp, alvo.current_hp + quantidade)

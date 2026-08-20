# ==================================================
# Nome: AttackEffectResolver
# Categoria: Core / Combat / Data-Driven
# Responsável por ler a linguagem 'mec_*' do CardResource
# e resolver mecânicas de ataque e efeitos colaterais.
# ==================================================
class_name AttackEffectResolver
extends RefCounted

## ----------------------------------------------------
## 1. CÁLCULO DE DANO MODIFICADO / CONDICIONAL
## ----------------------------------------------------

## Retorna o dano total considerando mecânicas condicionais e modificadores
static func calcular_dano_ataque(
	carta: CardResource,
	atacante: AnimalInstance,
	defensor: AnimalInstance,
	jogador_atacante_id: int
) -> int:
	var dano_calculado: int = carta.damage_base

	if carta.mec_trigger != "AO_ATACAR":
		return dano_calculado

	print("\n🔍 [AttackEffectResolver] Avaliando mecânica de dano para '%s'..." % carta.name)
	print("   └─ Dano Base: %d | Tipo Dano: '%s' | Ação: '%s' | Condição: '%s'" % [
		dano_calculado, carta.damage_type, carta.mec_action, carta.mec_condition
	])

	var condicao_atendida: bool = _validar_condicao(carta, atacante, defensor, jogador_atacante_id)

	if not condicao_atendida:
		print("❌ [AttackEffectResolver] Condição NÃO atendida. Mantendo dano base de %d." % dano_calculado)
		return dano_calculado

	print("✅ [AttackEffectResolver] Condição ATENDIDA! Processando modificador de dano...")

	match carta.damage_type:
		"FIXO":
			dano_calculado = carta.mec_quantity
			print("💥 [AttackEffectResolver] Dano FIXO aplicado: %d" % dano_calculado)

		"MULTIPLICADOR":
			var mult: int = carta.mec_quantity if carta.mec_quantity > 0 else 1
			dano_calculado = carta.damage_base * mult
			print("💥 [AttackEffectResolver] Dano MULTIPLICADO (x%d): Novo dano = %d" % [mult, dano_calculado])

		"CONDICIONAL":
			if carta.mec_action in ["AUMENTAR_ATAQUE", "MODIFICAR_DANO_CAUSADO"]:
				dano_calculado += carta.mec_quantity
				print("💥 [AttackEffectResolver] Dano Condicional (+%d) aplicado! Novo dano: %d" % [carta.mec_quantity, dano_calculado])
			elif carta.mec_action == "DIMINUIR_ATAQUE":
				dano_calculado = max(0, dano_calculado - carta.mec_quantity)
				print("💥 [AttackEffectResolver] Dano Reduzido (-%d)! Novo dano: %d" % [carta.mec_quantity, dano_calculado])

		"EFEITO":
			# Dano gerenciado diretamente pela ação
			pass

	return max(0, dano_calculado)


## ----------------------------------------------------
## 2. VALIDAÇÃO DE CONDIÇÕES (mec_condition)
## ----------------------------------------------------

static func _validar_condicao(
	carta: CardResource,
	atacante: AnimalInstance,
	defensor: AnimalInstance,
	jogador_atacante_id: int
) -> bool:
	match carta.mec_condition:
		"SEMPRE":
			return true

		"MOEDA":
			return _resolver_teste_moeda(carta.mec_custom_json)

		"ESTAGIO", "DESENVOLVIMENTO":
			if defensor != null and defensor.card != null:
				var estagio_alvo: String = defensor.card.stage.to_upper()
				var estagio_esperado: String = carta.mec_filter_stage.to_upper()
				return (estagio_esperado == "QUALQUER") or (estagio_alvo == estagio_esperado)
			return false

		"STATUS":
			if defensor != null:
				return _animal_tem_status(defensor, carta.mec_status_name)
			return false

		"CONDICAO_ENERGIA":
			if atacante != null:
				return atacante.attached_energies.size() >= carta.mec_quantity
			return false

		"NO_BANCO":
			var id_oponente: int = 1 if jogador_atacante_id == 0 else 0
			var banco_oponente: Array = GameState.obter_banco(id_oponente)
			return not banco_oponente.is_empty()

		"NO_ATIVO":
			return defensor != null

		_:
			print("⚠️ [AttackEffectResolver] Condição desconhecida ou não mapeada: '%s'" % carta.mec_condition)
			return false


## ----------------------------------------------------
## 3. RESOLUÇÃO DE EFEITOS PÓS-DANO (mec_action)
## ----------------------------------------------------

## Esta função é assíncrona (suporta await) quando há interação de interface
static func processar_efeito_pos_ataque(
	carta: CardResource,
	atacante: AnimalInstance,
	defensor: AnimalInstance,
	jogador_atacante_id: int
) -> void:
	if carta.mec_trigger != "AO_ATACAR":
		return

	if not _validar_condicao(carta, atacante, defensor, jogador_atacante_id):
		return

	print("\n🧪 [AttackEffectResolver] Processando ação pós-ataque Data-Driven: '%s'..." % carta.mec_action)

	# Linha 130-131 — troca a chamada síncrona por await:
	var id_jogador_alvo: int = _resolver_alvo_jogador(carta.mec_target_player, jogador_atacante_id)
	var alvo_instancia: AnimalInstance = await _resolver_alvo_instancia(carta, atacante, defensor, jogador_atacante_id)

	match carta.mec_action:

		# --- AÇÕES DE ANIMAIS / MESA ---
		"APLICAR_STATUS":
			if alvo_instancia != null and carta.mec_status_name != "NENHUM":
				_aplicar_status_no_alvo(alvo_instancia, carta.mec_status_name, carta.mec_duration)

		"CURAR":
			if alvo_instancia != null and carta.mec_quantity > 0:
				var hp_antes: int = alvo_instancia.current_hp
				alvo_instancia.current_hp = mini(alvo_instancia.card.hp, alvo_instancia.current_hp + carta.mec_quantity)
				print("💚 [Ataque] %s curou %d HP (%d -> %d)." % [alvo_instancia.card.name, carta.mec_quantity, hp_antes, alvo_instancia.current_hp])

		"ALIMENTAR":
			if alvo_instancia != null:
				var player_state = GameState.obter_jogador_state(jogador_atacante_id)
				var qtd: int = carta.mec_quantity if carta.mec_quantity > 0 else 1
				if player_state and player_state.comida_disponivel >= qtd:
					alvo_instancia.adicionar_comida(qtd)
					player_state.comida_disponivel -= qtd
					print("🍖 [Ataque] %s recebeu %d de comida." % [alvo_instancia.card.name, qtd])

		"DESNUTRIR":
			if alvo_instancia != null:
				var qtd: int = carta.mec_quantity if carta.mec_quantity > 0 else 1
				alvo_instancia.remover_comida(qtd)
				print("📉 [Ataque] %s perdeu %d de comida." % [alvo_instancia.card.name, qtd])

		# Linha 161-163 — ENERGIZAR agora envia o filtro de cor:
		"ENERGIZAR":
			print("⚡ [Ataque] Solicitando energizar '%s' com %d energia(s) [cor: %s]..." % [alvo_instancia.card.name if alvo_instancia else "Nulo", carta.mec_quantity, carta.mec_filter_color])
			await BattleManager.solicitar_energizar_animal(id_jogador_alvo, alvo_instancia, carta.mec_origin_zone, carta.mec_filter_color, carta.mec_quantity)

		"PUXAR":
			var id_oponente: int = 1 if jogador_atacante_id == 0 else 0
			print("🧲 [Ataque] 'PUXAR': Solicitando alvo no banco do oponente ID %d..." % id_oponente)
			await BattleManager.solicitar_selecao_banco_oponente(jogador_atacante_id, id_oponente, "puxar_banco", 1)

		"EXPULSAR", "RECUAR":
			if id_jogador_alvo != -1:
				print("🔄 [Ataque] Solicitando troca forçada para Jogador %d (%s)..." % [id_jogador_alvo, carta.mec_action])
				await BattleManager.solicitar_troca_forcada(id_jogador_alvo)   # 👈 era TurnManager

		# --- AÇÕES DE BARALHO / MÃO / DECK ---
		"COMPRAR":
			var qtd: int = carta.mec_quantity if carta.mec_quantity > 0 else 1
			for i in range(qtd):
				DeckManager.comprar_carta(id_jogador_alvo)
			print("🃏 [Ataque] Jogador %d comprou %d carta(s)." % [id_jogador_alvo, qtd])

		"BUSCAR":
			print("🔍 [Ataque] Solicitando busca de %d carta(s) na zona '%s'..." % [carta.mec_quantity, carta.mec_origin_zone])
			await BattleManager.solicitar_busca_cartas_zona(
				id_jogador_alvo, 
				carta.mec_origin_zone, 
				carta.mec_filter_color, 
				carta.mec_filter_stage, 
				carta.mec_quantity
			)

		"OLHAR":
			print("👁️ [Ataque] Solicitando visualizar as %d primeiras cartas do Deck..." % carta.mec_quantity)
			await BattleManager.solicitar_olhar_topo_deck(id_jogador_alvo, carta.mec_quantity)

		"DEVOLVER":
			print("↩️ [Ataque] Solicitando devolver carta da %s para o %s..." % [carta.mec_origin_zone, carta.mec_target_zone])
			await BattleManager.solicitar_devolver_carta(id_jogador_alvo, carta.mec_origin_zone, carta.mec_target_zone, carta.mec_quantity)

		"EMBARALHAR":
			DeckManager.embaralhar_deck(id_jogador_alvo)
			print("🔀 [Ataque] Deck do Jogador %d embaralhado." % id_jogador_alvo)

		"REORGANIZAR":
			print("📋 [Ataque] Solicitando reorganização do topo do Deck para o Jogador %d..." % id_jogador_alvo)
			await BattleManager.solicitar_reorganizar_topo(id_jogador_alvo, carta.mec_quantity)

		"DESCARTAR":
			await _executar_descarte(carta, alvo_instancia, id_jogador_alvo)

		# --- AÇÕES GLOBAIS / MODIFICADORES ---
		"BLOQUEAR_ACOES":
			if alvo_instancia != null and carta.mec_blocked_action != "NENHUM":
				var flag_bloqueio: String = "BLOQUEADO_" + carta.mec_blocked_action
				if not alvo_instancia.conditions.has(flag_bloqueio):
					alvo_instancia.conditions.append(flag_bloqueio)
					print("🚫 [Ataque] Ação '%s' foi BLOQUEADA em %s." % [carta.mec_blocked_action, alvo_instancia.card.name])

		"MODIFICAR_CUSTO":
			print("🏷️ [Ataque] Modificando custo de '%s' em %d para o Jogador %d..." % [carta.mec_resource, carta.mec_quantity, id_jogador_alvo])
			BattleManager.aplicar_modificador_custo(id_jogador_alvo, carta.mec_resource, carta.mec_quantity, carta.mec_duration)

		"AUMENTAR_ATAQUE", "DIMINUIR_ATAQUE":
			# Já tratados na etapa de cálculo de dano
			pass
		
		_:
			_embaralhar_se_necessario(carta, id_jogador_alvo)	
			print("ℹ️ [AttackEffectResolver] Ação '%s' não requer processamento pós-ataque ou é passiva." % carta.mec_action)


## ----------------------------------------------------
## 4. HELPERS DE SUPORTE
## ----------------------------------------------------

static func _resolver_alvo_jogador(target_player_enum: String, jogador_atacante_id: int) -> int:
	match target_player_enum:
		"DONO":
			return jogador_atacante_id
		"ADVERSARIO":
			return 1 if jogador_atacante_id == 0 else 0
		"AMBOS":
			return -1 # Caso especial para efeitos globais
		_:
			return jogador_atacante_id


static func _resolver_alvo_instancia(carta: CardResource, atacante: AnimalInstance, defensor: AnimalInstance, jogador_atacante_id: int) -> AnimalInstance:
	match carta.mec_target_zone:
		"ATIVO":
			return defensor if carta.mec_target_player == "ADVERSARIO" else atacante

		"BANCO", "ATIVO_BANCO":
			var id_dono: int = _resolver_alvo_jogador(carta.mec_target_player, jogador_atacante_id)
			if id_dono == -1:
				return atacante # "AMBOS" não faz sentido pra alvo único — fallback seguro

			var candidatos: Array = []
			if carta.mec_target_zone == "ATIVO_BANCO":
				var ativo: AnimalInstance = GameState.obter_ativo(id_dono)
				if ativo != null:
					candidatos.append(ativo)
			candidatos.append_array(GameState.obter_banco(id_dono))

			return await BattleManager.solicitar_selecao_alvo_efeito(id_dono, candidatos, "alvo_efeito_ataque")

		_:
			return defensor if carta.mec_target_player == "ADVERSARIO" else atacante

static func _animal_tem_status(animal: AnimalInstance, status_enum_str: String) -> bool:
	if animal == null or status_enum_str == "NENHUM":
		return false

	var enum_tipo: ConditionSystem.Tipo = _string_para_condition_enum(status_enum_str)
	if enum_tipo != ConditionSystem.Tipo.NENHUMA:
		return ConditionSystem.possui_condicao(animal, enum_tipo)

	return false


static func _aplicar_status_no_alvo(alvo: AnimalInstance, status_enum_str: String, duracao: int) -> void:
	var enum_tipo: ConditionSystem.Tipo = _string_para_condition_enum(status_enum_str)
	if enum_tipo != ConditionSystem.Tipo.NENHUMA:
		if not ConditionSystem.possui_condicao(alvo, enum_tipo):
			ConditionSystem.aplicar_condicao(alvo, enum_tipo)
			print("☣️ [Ataque] Status '%s' aplicado em %s por %d turnos." % [status_enum_str, alvo.card.name, duracao])


static func _string_para_condition_enum(status_str: String) -> ConditionSystem.Tipo:
	match status_str.to_upper():
		"ENVENENADO": return ConditionSystem.Tipo.ENVENENADO
		"PARALISADO": return ConditionSystem.Tipo.PARALISADO
		"SANGRANDO":  return ConditionSystem.Tipo.SANGRANDO
		"ADORMECIDO": return ConditionSystem.Tipo.ADORMECIDO
		"CONDENADO":  return ConditionSystem.Tipo.CONDENADO
		"PROTEGIDO":  return ConditionSystem.Tipo.PROTEGIDO
		"IMUNE":      return ConditionSystem.Tipo.IMUNE
		"PRESO":      return ConditionSystem.Tipo.PRESO
		"RECARREGANDO": return ConditionSystem.Tipo.RECARREGANDO
		_: return ConditionSystem.Tipo.NENHUMA


static func _executar_descarte(carta: CardResource, alvo_instancia: AnimalInstance, jogador_id: int) -> void:
	var qtd: int = carta.mec_quantity if carta.mec_quantity > 0 else 1
	
	match carta.mec_resource:
		"ENERGIA":
			if alvo_instancia != null and not alvo_instancia.attached_energies.is_empty():
				print("🗑️ [Descarte] Solicitando descarte de %d energia(s) de %s..." % [qtd, alvo_instancia.card.name])
				await BattleManager.solicitar_descarte_energia_animal(jogador_id, alvo_instancia, qtd)
		"CARTA":
			print("🗑️ [Descarte] Solicitando descarte de %d carta(s) da mão do Jogador %d..." % [qtd, jogador_id])
			await BattleManager.solicitar_descarte_mao(jogador_id, qtd)
		"COMIDA":
			if alvo_instancia != null:
				alvo_instancia.remover_comida(qtd)
				print("🗑️ [Descarte] %d comida(s) descartada(s) de %s." % [qtd, alvo_instancia.card.name])


static func _resolver_teste_moeda(custom_json_str: String) -> bool:
	var custom_data: Dictionary = _parse_custom_json(custom_json_str)
	var qtd_moedas: int = int(custom_data.get("quantidade_moedas", 1))
	var caras_necessarias: int = int(custom_data.get("caras_necessarias", 1))

	var caras_obtidas: int = 0
	for i in range(qtd_moedas):
		if randf() >= 0.5:
			caras_obtidas += 1

	print("🪙 [Moeda] Lançou %d moedas. Caras obtidas: %d (Necessárias: %d)" % [qtd_moedas, caras_obtidas, caras_necessarias])
	return caras_obtidas >= caras_necessarias

## Regra implícita de TCG: qualquer ação que dê acesso/movimente cartas
## do deck deve embaralhar depois, pra preservar aleatoriedade. Exceção:
## REORGANIZAR (o jogador está deliberadamente definindo a ordem) e
## COMPRAR (compra normal, não é "efeito de busca").
static func _embaralhar_se_necessario(carta: CardResource, jogador_id: int) -> void:
	var toca_deck: bool = false
	match carta.mec_action:
		"BUSCAR", "ENERGIZAR", "OLHAR":
			toca_deck = (carta.mec_origin_zone == "DECK")
		"DEVOLVER":
			toca_deck = (carta.mec_target_zone == "DECK")

	if toca_deck:
		DeckManager.embaralhar_deck(jogador_id)
		print("🔀 [Ataque] Deck do Jogador %d embaralhado automaticamente após '%s'." % [jogador_id, carta.mec_action])

static func _parse_custom_json(json_str: String) -> Dictionary:
	if json_str.is_empty():
		return {}
	var json = JSON.new()
	if json.parse(json_str) == OK and json.data is Dictionary:
		return json.data
	return {}

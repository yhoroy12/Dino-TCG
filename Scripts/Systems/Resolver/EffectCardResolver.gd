class_name EffectCardResolver
extends Node

## Resolver central para interpretar e processar cartas de efeito (Cataclismos, Vestígios e Territórios).
## Lê os campos mec_* do EffectResource traduzidos do CSV Data-Driven.

# ==============================================================================
# 1. DICIONÁRIOS E MAPEAMENTOS RÁPIDOS
# ==============================================================================

const TAG_MAP: Dictionary = {
	"dano_causado": EffectSystem.TAG_BONUS_DANO,
	"dano_recebido": EffectSystem.TAG_REDUCAO_DANO,
	"multiplicador": EffectSystem.TAG_MULTIPLICADOR_DANO
}

const SCOPE_MAP: Dictionary = {
	"turno_atual": EffectSystem.Escopo.TURNO_ATUAL,
	"proximo_turno_adversario": EffectSystem.Escopo.TURNOS_DO_DONO, # Mapeado conforme o tipo de duracao
	"permanente": EffectSystem.Escopo.PERMANENTE
}


# ==============================================================================
# 2. FUNÇÕES GERAIS (PONTES DE ENTRADA)
# ==============================================================================

## Ponto de entrada chamado pelo BattleManager ao jogar uma carta de efeito
static func executar_carta_efeito(carta: EffectResource, jogador_id: int, contexto: Dictionary) -> Dictionary:
	if not carta:
		return {"sucesso": false, "motivo": "carta_invalida"}

	match carta.super_type.to_lower():
		"cataclismo":
			return _resolver_cataclismo(carta, jogador_id, contexto)
		"vestigio":
			return _resolver_vestigio(carta, jogador_id, contexto)
		"territorio":
			return _resolver_territorio(carta, jogador_id, contexto)
		_:
			return {"sucesso": false, "motivo": "super_tipo_desconhecido"}


# ==============================================================================
# 3. FUNÇÕES PARA CATACLISMO
# ==============================================================================

static func _resolver_cataclismo(carta: EffectResource, jogador_id: int, contexto: Dictionary) -> Dictionary:
	var json_custom: Dictionary = _parse_custom_json(carta.mec_custom_json)
	var acao: String = carta.mec_action.to_lower()

	match acao:
		"comprar":
			return _cataclismo_comprar_cartas(carta, jogador_id, contexto, json_custom)
			
		"modificar_dano_causado", "modificar_dano_recebido":
			return _cataclismo_modificar_dano(carta, jogador_id, contexto, json_custom)
			
		"curar":
			return _cataclismo_curar(carta, jogador_id, contexto, json_custom)
			
		"descartar":
			if carta.mec_resource == "energia":
				return _cataclismo_descartar_energia(carta, jogador_id, contexto, json_custom)
			return {"sucesso": false, "motivo": "recurso_descarte_nao_suportado"}
			
		"puxar":
			return _cataclismo_puxar_ou_resgatar(carta, jogador_id, contexto, json_custom)
			
		"adicionar_comida", "fornecer_comida":
			return _cataclismo_manipular_comida(carta, jogador_id, contexto, json_custom)
			
		"zerar_custo", "modificar_custo":
			return _cataclismo_modificar_custo_recuo(carta, jogador_id, contexto, json_custom)
			
		"forcar_recuo":
			return _cataclismo_recuo_tatico(carta, jogador_id, contexto)
			
		"puxar_banco_adversario", "forcar_troca_adversario":
			return _cataclismo_emboscada(carta, jogador_id, contexto)
			
		_:
			print("[EffectCardResolver] Ação de Cataclismo não reconhecida: ", acao)
			return {"sucesso": false, "motivo": "acao_cataclismo_invalida"}


## A116 (Chuva de Meteoros), A124 (Mãos Frágeis)
static func _cataclismo_comprar_cartas(carta: EffectResource, jogador_id: int, contexto: Dictionary, custom_json: Dictionary) -> Dictionary:
	var quantidade: int = int(carta.mec_quantity)
	var eh_todos: bool = (carta.mec_target_player == "todos_jogadores")
	var jogadores_afetados: Array[int] = [0, 1] if eh_todos else [jogador_id]

	for pid in jogadores_afetados:
		# Lógica de descarte/embaralhar mão antes de comprar
		if custom_json.get("resetar_mao_antes", false):
			# Regra Chuva de Meteoros: Embaralha mão no deck antes de comprar
			var mao_atual: Array = GameState.obter_mao(pid)
			GameState.embaralhar_cartas_no_deck(pid, mao_atual)
			GameState.limpar_mao(pid)
		elif custom_json.get("descartar_mao", false):
			# Regra Mãos Frágeis: Descarta a mão antes de comprar
			var mao_atual: Array = GameState.obter_mao(pid)
			GameState.mover_para_descarte(pid, mao_atual)
			GameState.limpar_mao(pid)

		# Executa a compra das cartas via DeckManager/GameState
		GameState.comprar_cartas_do_deck(pid, quantidade)

	return {"sucesso": true, "mensagem": "Compradas %d cartas" % quantidade}


## A118 (Presas Afiadas), A121 (Pele Rígida), A127 (Pele Escamosa)
static func _cataclismo_modificar_dano(carta: EffectResource, jogador_id: int, contexto: Dictionary, custom_json: Dictionary) -> Dictionary:
	var alvos: Array = _resolver_alvos(carta.mec_target_player, carta.mec_target_zone, jogador_id, contexto)
	alvos = _filtrar_animais(alvos, carta.mec_filter_color, carta.mec_filter_stage)

	if alvos.is_empty():
		return {"sucesso": false, "motivo": "sem_alvos_validos"}

	var valor: float = carta.mec_quantity
	var tag: String = TAG_MAP.get("dano_causado") if carta.mec_action == "modificar_dano_causado" else TAG_MAP.get("dano_recebido")
	
	var duracao_str: String = custom_json.get("tipo_duracao", "turno_atual")
	var escopo = SCOPE_MAP.get(duracao_str, EffectSystem.Escopo.TURNO_ATUAL)

	for animal in alvos:
		EffectSystem.aplicar_efeito(
			animal,
			tag,
			valor,
			escopo,
			1, # Duração em turnos
			carta.id
		)
		
		if custom_json.get("anular_fraqueza", false):
			EffectSystem.aplicar_efeito(animal, "anular_fraqueza", 1.0, escopo, 1, carta.id)

	return {"sucesso": true, "afetados": alvos.size()}


## A117 (Local de descanso seguro)
static func _cataclismo_curar(carta: EffectResource, jogador_id: int, contexto: Dictionary, custom_json: Dictionary) -> Dictionary:
	var alvo = contexto.get("alvo_instancia", null)
	if not alvo:
		return {"sucesso": false, "motivo": "alvo_nao_selecionado"}

	var cura_val: int = int(carta.mec_quantity)
	alvo.curar_hp(cura_val)

	if custom_json.get("remover_status", "") == "todos":
		alvo.limpar_status_negativos()

	return {"sucesso": true, "hp_curado": cura_val}


## A119 (Esgotamento)
static func _cataclismo_descartar_energia(carta: EffectResource, jogador_id: int, contexto: Dictionary, custom_json: Dictionary) -> Dictionary:
	var adv_id: int = 1 - jogador_id
	var ativo_adv = GameState.obter_dinossauro_ativo(adv_id)

	if not ativo_adv or ativo_adv.energias.is_empty():
		return {"sucesso": false, "motivo": "adversario_sem_energias"}

	var qtd_descarte: int = 0
	if custom_json.get("tipo_loop", "") == "ate_coroa":
		qtd_descarte = _rodar_moeda_loop("ate_coroa")
	else:
		qtd_descarte = int(carta.mec_quantity)

	if qtd_descarte > 0:
		ativo_adv.remover_energias(qtd_descarte)

	return {"sucesso": true, "energias_removidas": qtd_descarte}


## A120 (Proteger o Ninho), A123 (Ataque Revezado), A125 (Resgate Fóssil), A130, A131
static func _cataclismo_puxar_ou_resgatar(carta: EffectResource, jogador_id: int, contexto: Dictionary, custom_json: Dictionary) -> Dictionary:
	# A120: Proteger o ninho (Resgatar dinossauro do descarte para a mão)
	if carta.mec_resource == "carta" and carta.mec_origin_zone == "descarte":
		var carta_resgatada = contexto.get("carta_selecionada_descarte", null)
		if not carta_resgatada:
			return {"sucesso": false, "motivo": "carta_descarte_nao_selecionada"}
		
		GameState.remover_do_descarte(jogador_id, carta_resgatada)
		GameState.adicionar_a_mao(jogador_id, carta_resgatada)
		return {"sucesso": true}

	# A123: Ataque Revezado (Mover energia do banco para o ativo)
	if carta.mec_resource == "energia" and carta.mec_origin_zone == "escolha_banco_dono":
		var orig = contexto.get("origem_banco", null)
		var dest = GameState.obter_dinossauro_ativo(jogador_id)
		if orig and dest and orig.energias.size() > 0:
			var e = orig.remover_uma_energia()
			dest.anexar_energia(e)
			return {"sucesso": true}
		return {"sucesso": false, "motivo": "transferencia_energia_invalida"}

	# A125: Resgate Fóssil (Retorna ativo para a mão e descarta anexadas)
	if custom_json.get("destino", "") == "mao" and custom_json.get("descartar_anexadas", false):
		var ativo = GameState.obter_dinossauro_ativo(jogador_id)
		if ativo:
			ativo.descartar_todas_anexadas()
			GameState.mover_ativo_para_mao(jogador_id)
			return {"sucesso": true}

	# A131: Força Marrom (Puxar energia do deck)
	if carta.mec_resource == "energia" and carta.mec_origin_zone == "deck":
		var alvo = contexto.get("alvo_instancia", null)
		if alvo and (_checar_restricao_cor(alvo, custom_json)):
			var energia_deck = GameState.remover_energia_do_deck(jogador_id)
			if energia_deck:
				alvo.anexar_energia(energia_deck)
				return {"sucesso": true}
		return {"sucesso": false, "motivo": "alvo_invalido_ou_deck_sem_energia"}

	return {"sucesso": false, "motivo": "puxar_nao_implementado"}


## A129 (Super Alimentação) e A130 (Roubar Comida)
static func _cataclismo_manipular_comida(carta: EffectResource, jogador_id: int, contexto: Dictionary, custom_json: Dictionary) -> Dictionary:
	var alvo = contexto.get("alvo_instancia", null)
	if not alvo:
		return {"sucesso": false, "motivo": "alvo_comida_nao_selecionado"}

	var qtd: int = int(carta.mec_quantity)
	
	if carta.mec_action in ["adicionar_comida", "fornecer_comida"]:
		alvo.adicionar_comida(qtd)
	elif carta.mec_action == "puxar" and carta.mec_resource == "comida": # A130 Roubar Comida
		alvo.remover_comida(qtd)

	return {"sucesso": true}


## A126 (Peso Pena)
static func _cataclismo_modificar_custo_recuo(carta: EffectResource, jogador_id: int, contexto: Dictionary, custom_json: Dictionary) -> Dictionary:
	var alvos = GameState.obter_todos_dinossauros_campo(jogador_id)
	var mod_custo: int = int(carta.mec_quantity)

	for dinossauro in alvos:
		EffectSystem.aplicar_efeito(
			dinossauro,
			"modificador_custo_recuo",
			mod_custo,
			EffectSystem.Escopo.TURNO_ATUAL,
			1,
			carta.id
		)
	return {"sucesso": true}


## A128 (Recuo Tático)
static func _cataclismo_recuo_tatico(carta: EffectResource, jogador_id: int, contexto: Dictionary) -> Dictionary:
	var ativo = GameState.obter_dinossauro_ativo(jogador_id)
	var banco = GameState.obter_banco(jogador_id)

	if not ativo or banco.is_empty():
		return {"sucesso": false, "motivo": "recuo_impossivel_sem_banco"}

	GameState.forcar_troca_ativo_banco(jogador_id, contexto.get("novo_ativo_instancia", null))
	return {"sucesso": true}


## A122 (Emboscada)
static func _cataclismo_emboscada(carta: EffectResource, jogador_id: int, contexto: Dictionary) -> Dictionary:
	var adv_id: int = 1 - jogador_id
	var alvo_banco = contexto.get("alvo_instancia", null)

	# Valida se o alvo do banco rival possui contadores de dano
	if alvo_banco and alvo_banco.dano_acumulado > 0:
		GameState.forcar_troca_ativo_banco(adv_id, alvo_banco)
		return {"sucesso": true}

	return {"sucesso": false, "motivo": "alvo_invalido_deve_ter_dano"}


# ==============================================================================
# 4. FUNÇÕES PARA VESTÍGIO (STUB / EXPANSÃO FUTURA)
# ==============================================================================

static func _resolver_vestigio(carta: EffectResource, jogador_id: int, contexto: Dictionary) -> Dictionary:
	print("[EffectCardResolver] Processando Vestígio: ", carta.name)
	return {"sucesso": true, "status": "vestigio_processado"}


# ==============================================================================
# 5. FUNÇÕES PARA TERRITÓRIO (STUB / EXPANSÃO FUTURA)
# ==============================================================================

static func _resolver_territorio(carta: EffectResource, jogador_id: int, contexto: Dictionary) -> Dictionary:
	print("[EffectCardResolver] Processando Território: ", carta.name)
	return {"sucesso": true, "status": "territorio_processado"}


# ==============================================================================
# 6. FUNÇÕES REAPROVEITÁVEIS (HELPERS & UTILITY)
# ==============================================================================

## Retorna lista de instâncias com base no jogador e zona especificados
static func _resolver_alvos(mec_target_player: String, mec_target_zone: String, jogador_id: int, contexto: Dictionary) -> Array:
	var alvos: Array = []
	var pid: int = jogador_id if mec_target_player == "dono" else (1 - jogador_id)

	match mec_target_zone:
		"ativo":
			var a = GameState.obter_dinossauro_ativo(pid)
			if a: alvos.append(a)
		"todos_campo":
			alvos = GameState.obter_todos_dinossauros_campo(pid)
		"escolha_campo":
			if contexto.has("alvo_instancia"):
				alvos.append(contexto["alvo_instancia"])

	return alvos


## Filtra uma lista de unidades por cor e/ou estágio evolutivo
static func _filtrar_animais(animais: Array, cor: String, estagio: String) -> Array:
	var filtrados: Array = []
	for a in animais:
		var cor_ok: bool = (cor == "" or cor == "nan" or a.cor.to_lower() == cor.to_lower())
		var estagio_ok: bool = (estagio == "" or estagio == "nan" or a.estagio.to_lower() == estagio.to_lower())
		if cor_ok and estagio_ok:
			filtrados.append(a)
	return filtrados


## Rola moeda consecutiva até sair coroa (Esgotamento)
static func _rodar_moeda_loop(tipo_loop: String) -> int:
	var caras: int = 0
	if tipo_loop == "ate_coroa":
		while randf() >= 0.5:
			caras += 1
	return caras


## Valida se o alvo cumpre restrições do JSON
static func _checar_restricao_cor(alvo, custom_json: Dictionary) -> bool:
	var restr = custom_json.get("restricao_alvo", {})
	if restr.has("cor"):
		return alvo.cor.to_lower() == restr["cor"].to_lower()
	return true


## Transforma a string de JSON do CSV em um Dicionário seguro
static func _parse_custom_json(json_str: String) -> Dictionary:
	if json_str == "" or json_str == "nan" or json_str == null:
		return {}
	
	var json = JSON.new()
	var error = json.parse(json_str)
	if error == OK:
		return json.data
	return {}

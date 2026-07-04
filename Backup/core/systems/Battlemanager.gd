extends Node

# ==============================================================================
# BattleManager — Processador de Combate (core/systems/BattleManager.gd)
# Instanciado na Arena. Processa efeitos textuais, tipos de dano e modificadores.
# Depende diretamente de GameState (Autoload).
# ==============================================================================

signal efeito_resolvido(descricao: String)
@warning_ignore("unused_signal")
signal moeda_batalha_lancada(efeito_nome: String, resultado: bool)

# -----------------------------------------------------------------------------
# RESOLUÇÃO PRINCIPAL DE ATAQUE
# -----------------------------------------------------------------------------
## Acionado pelo controlador da arena para calcular e aplicar o dano e efeitos
func resolver_ataque(jogador_id: int) -> void:
	var j = GameState.jogadores[jogador_id]
	var op_id := 1 if jogador_id == 0 else 0
	var j_oponente = GameState.jogadores[op_id]
	
	# Usamos a nova chave "zona_ativo" que guarda o CardResource tipado
	var carta_ativa: CardResource = j["zona_ativo"]
	var defensor_ativo: CardResource = j_oponente["zona_ativo"]
	
	if carta_ativa == null:
		return

	# Puxa os dados diretos das propriedades nativas do Resource
	var dano_base: int = carta_ativa.damage_base
	var ataque_nome: String = carta_ativa.attack_name
	var efeito: String = carta_ativa.text_ui.to_lower().strip_edges()

	# 1. Inferência Inteligente do Tipo de Dano
	# (Baseado no texto, elimina a necessidade de uma coluna exclusiva de 'dano_tipo')
	var dano_tipo := "fixo"
	if dano_base == 0:
		dano_tipo = "efeito"
	elif "moeda" in efeito:
		dano_tipo = "multiplicador"
	elif "+20" in efeito or "+30" in efeito or "condição" in efeito or "status" in efeito or "adulto" in efeito:
		dano_tipo = "condicional"

	var dano_final := 0

	# 2. Processamento do Dano
	match dano_tipo:
		"fixo":
			dano_final = dano_base
		"condicional":
			dano_final = _calcular_dano_condicional(op_id, dano_base, efeito, carta_ativa)
		"multiplicador":
			dano_final = _calcular_dano_multiplicador(dano_base, efeito, ataque_nome)
		"efeito":
			dano_final = 0 # Ataques de suporte ou puramente alteradores de status

	# 3. Aplicação de Fraquezas e Resistências (Se houver defensor)
	if dano_final > 0 and defensor_ativo != null:
		dano_final = _aplicar_fraqueza_e_resistencia(dano_final, carta_ativa, defensor_ativo)

	# 4. Execução dos Efeitos Secundários de Texto
	if efeito != "":
		_processar_efeito_texto(efeito, jogador_id, op_id)

	# 5. Aplicação direta no GameState
	if dano_final > 0 and defensor_ativo != null:
		# A mágica acontece aqui: O GameState já tira o HP e processa o Nocaute automaticamente!
		print("⚔️ Batalha: %s processou %d de dano final." % [ataque_nome, dano_final])
		GameState.aplicar_dano_ativo(op_id, dano_final)


# -----------------------------------------------------------------------------
# CALCULADORES ESPECÍFICOS DE COMBATE
# -----------------------------------------------------------------------------

func _calcular_dano_condicional(op_id: int, base: int, efeito: String, atacante: CardResource) -> int:
	var j_oponente = GameState.jogadores[op_id]
	
	# Exemplo Rulebook: "Causa +20 se o oponente tiver uma condição especial ativa"
	if "condicao" in efeito or "status" in efeito or "condição" in efeito:
		if j_oponente["condicao"] != GameState.Condicao.NENHUMA:
			return base + 20
			
	# Exemplo Rulebook: "Causa +30 se o atacante for um bicho de estágio Adulto"
	if "adulto" in efeito:
		if atacante.stage.to_lower().strip_edges() == "adulto":
			return base + 30
			
	return base

func _calcular_dano_multiplicador(base: int, efeito: String, ataque_nome: String) -> int:
	if "moeda" in efeito:
		var caras := 0
		var vezes := 1
		
		# Detecta múltiplos lançamentos
		if "2" in efeito or "duas" in efeito: vezes = 2
		elif "3" in efeito or "tres" in efeito: vezes = 3
			
		for i in range(vezes):
			var caiu_cara = GameState.lancar_moeda(ataque_nome) # Usa a função oficial do GameState
			if caiu_cara:
				caras += 1
				
		print("🎲 Moedas do ataque %s: %d Caras obtidas." % [ataque_nome, caras])
		return base * caras
		
	return base

func _aplicar_fraqueza_e_resistencia(dano: int, atacante: CardResource, defensor: CardResource) -> int:
	var cor_atacante: String = atacante.color.to_lower().strip_edges()
	
	# Usamos get() de forma segura, assim o jogo não quebra caso a sua classe CardResource 
	# Busca segura para fraqueza (tenta inglês, se for nulo tenta português)
	var val_fraqueza = defensor.get("weakness")
	if val_fraqueza == null:
		val_fraqueza = defensor.get("fraqueza")
	var fraqueza: String = str(val_fraqueza if val_fraqueza != null else "").to_lower().strip_edges()
	
	# Busca segura para resistência (tenta inglês, se for nulo tenta português)
	var val_resistencia = defensor.get("resistance")
	if val_resistencia == null:
		val_resistencia = defensor.get("resistencia")
	var resistencia: String = str(val_resistencia if val_resistencia != null else "").to_lower().strip_edges()
	
	var dano_modificado = dano
	
	if cor_atacante == fraqueza and fraqueza != "":
		dano_modificado += 20 
		print("🔥 Fraqueza Aplicada! +20 de dano.")
		
	if cor_atacante == resistencia and resistencia != "":
		dano_modificado = clampi(dano_modificado - 20, 0, 9999)
		print("🛡️ Resistência Aplicada! -20 de dano.")
		
	return dano_modificado

# -----------------------------------------------------------------------------
# PROCESSADOR DE EFEITOS DE TEXTO (Parser de Habilidades de Ataque)
# -----------------------------------------------------------------------------
func _processar_efeito_texto(efeito: String, jogador_id: int, op_id: int) -> void:
	if "envenena" in efeito:
		GameState.aplicar_condicao_ativo(op_id, GameState.Condicao.ENVENENADO)
		emit_signal("efeito_resolvido", "O animal ativo do oponente foi Envenenado!")
		
	elif "sangra" in efeito:
		GameState.aplicar_condicao_ativo(op_id, GameState.Condicao.SANGRANDO)
		emit_signal("efeito_resolvido", "O animal ativo do oponente começou a Sangrar!")
		
	elif "paralisa" in efeito:
		GameState.aplicar_condicao_ativo(op_id, GameState.Condicao.PARALISADO)
		emit_signal("efeito_resolvido", "O animal ativo do oponente ficou Paralisado!")
		
	elif "cura filhotes" in efeito or "cura filhote" in efeito:
		_curar_filhotes_banco(jogador_id)
		emit_signal("efeito_resolvido", "Todos os seus Dinossauros Bebês no banco foram totalmente curados!")
		
	elif "força recuo" in efeito or "forca recuo" in efeito or "recuar" in efeito:
		_forcar_recuo_oponente(op_id)

# -----------------------------------------------------------------------------
# METODOS AUXILIARES DE EFEITO
# -----------------------------------------------------------------------------

## Como os dinos no banco agora são Resources completos com próprio HP mutável,
## para curar tudo, perguntamos a vida máxima original pro CardDatabase!
func _curar_filhotes_banco(jogador_id: int) -> void:
	var j = GameState.jogadores[jogador_id]
	for bicho in j["banco"]:
		if bicho is CardResource:
			var estagio = bicho.stage.to_lower().strip_edges()
			if estagio in ["filhote", "bebe", "bebê", "basico"]:
				var carta_original = CardDatabase.obter_carta(bicho.id)
				if carta_original:
					bicho.hp = carta_original.hp # Restaura a vida ao máximo original


func _forcar_recuo_oponente(op_id: int) -> void:
	var j_op = GameState.jogadores[op_id]
	
	if j_op["banco"].is_empty():
		print("ℹ️ Forçar recuo ignorado: O oponente não possui animais na reserva.")
		return
		
	emit_signal("efeito_resolvido", "O ataque forçou o animal do oponente a recuar! O oponente deve escolher quem vai subir.")

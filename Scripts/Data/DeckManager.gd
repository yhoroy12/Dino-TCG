extends Node

# ==============================================================================
# DeckManager — Autoload Singleton (core/autoloads/DeckManager.gd)
# Responsável pela persistência de IDs e conversão para objetos CardResource.
# ==============================================================================

# user:// é a pasta de dados do jogador gerenciada pelo Godot — existe e
# funciona automaticamente em qualquer SO/plataforma. Um path absoluto de
# Windows (ex: "C:/GameDev/...") só existe na máquina de quem o escreveu e
# quebra em qualquer outro computador, inclusive no build final do jogo.
const DIRETORIO_DECKS    := "user://decks/"
const TAMANHO_DECK_VALIDO := 60

func _ready() -> void:
	_criar_diretorio_se_nao_existir()


func _criar_diretorio_se_nao_existir() -> void:
	if not DirAccess.dir_exists_absolute(DIRETORIO_DECKS):
		DirAccess.make_dir_recursive_absolute(DIRETORIO_DECKS)


## Salva um deck a partir de uma lista plana de ids (com repetição, ex:
## ["trex_001", "trex_001", "trico_014"]). Agrupa por id + quantidade e
## grava no MESMO formato que carregar_lista_ids()/obter_deck_ativo()
## esperam — antes, salvar_deck() e carregar_lista_ids() usavam schemas
## de JSON diferentes ("cartas_ids" vs "colecao"), então todo deck salvo
## por aqui vinha vazio ao ser carregado. Corrigido agora: uma única
## fonte da verdade para o formato do arquivo de deck.
func salvar_deck(nome_deck: String, lista_ids: Array[String]) -> bool:
	if nome_deck.strip_edges() == "":
		return false

	var quantidades_por_id: Dictionary = {}

	for id in lista_ids:
		quantidades_por_id[id] = quantidades_por_id.get(id, 0) + 1

	var colecao: Array = []

	for id in quantidades_por_id.keys():
		colecao.append({
			"id": id,
			"quantidade": quantidades_por_id[id]
		})

	var dados_salvamento := {
		"nome": nome_deck,
		"colecao": colecao,
		"ativo": false
	}

	return salvar_deck_completo(dados_salvamento)


func carregar_lista_ids(nome_deck: String) -> Array:
	var dados := carregar_deck_completo(nome_deck)

	var lista_ids: Array = []

	if dados.has("colecao"):
		for entrada in dados["colecao"]:
			var id = entrada.get("id", "")
			var quantidade = entrada.get("quantidade", 0)

			for i in range(quantidade):
				lista_ids.append(id)

	return lista_ids


# ------------------------------------------------------------------------------
# CONVERSÃO PARA A ERA DOS RESOURCES
# ------------------------------------------------------------------------------
## Carrega o arquivo JSON do deck, pega os IDs salvos e devolve uma Array real
## cheia de CardResources tipados.
func carregar_deck_para_partida(nome_deck: String) -> Array[CardResource]:
	var lista_ids := carregar_lista_ids(nome_deck)

	var deck_de_resources: Array[CardResource] = []

	for id in lista_ids:
		# Pede ao CardDatabase a instância limpa do Resource nativo daquela carta.
		var recurso_carta = CardDatabase.obter_carta(id)

		if recurso_carta != null:
			deck_de_resources.append(recurso_carta)
		else:
			push_error("DeckManager: Falha crítica ao carregar carta ID: " + id + " para o deck da partida.")

	return deck_de_resources


func deck_existe(nome_deck: String) -> bool:
	return FileAccess.file_exists(DIRETORIO_DECKS + nome_deck + ".json")


func excluir_deck(nome_deck: String) -> bool:
	var caminho := DIRETORIO_DECKS + nome_deck + ".json"
	if FileAccess.file_exists(caminho):
		DirAccess.remove_absolute(caminho)
		return true
	return false


# ==============================================================================
# FUNÇÕES DE COMPATIBILIDADE COM A INTERFACE DE DECKS
# ==============================================================================

## Varre a pasta de decks salvos e retorna o nome de todos os arquivos (.json).
func obter_lista_de_decks_salvos() -> Array[String]:
	var lista: Array[String] = []
	var dir := DirAccess.open(DIRETORIO_DECKS)
	if dir:
		dir.list_dir_begin()
		var nome_arquivo = dir.get_next()
		while nome_arquivo != "":
			if not dir.current_is_dir() and nome_arquivo.ends_with(".json"):
				lista.append(nome_arquivo.replace(".json", ""))
			nome_arquivo = dir.get_next()
	return lista


## Verifica qual é o deck ativo selecionado.
func obter_deck_ativo() -> String:
	var lista := obter_lista_de_decks_salvos()
	for nome in lista:
		var dados := carregar_deck_completo(nome)
		if dados.get("ativo", false) == true:
			return nome
	return ""


## Lê o arquivo .json inteiro e retorna em formato de Dicionário para a UI
## extrair as informações.
func carregar_deck_completo(nome_deck: String) -> Dictionary:
	var caminho_arquivo: String = DIRETORIO_DECKS + nome_deck + ".json"
	if not FileAccess.file_exists(caminho_arquivo):
		return {}

	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.READ)
	var texto := arquivo.get_as_text()
	arquivo.close()

	var json := JSON.new()
	if json.parse(texto) != OK:
		return {}

	var dados = json.get_data()
	if typeof(dados) == TYPE_DICTIONARY:
		return dados
	return {}


## Permite que a UI salve modificações diretas no dicionário do deck (como
## marcar o estado de "ativo").
func salvar_deck_completo(dados_deck: Dictionary) -> bool:
	var nome_deck: String = str(dados_deck.get("nome", "")).strip_edges()
	if nome_deck == "":
		return false

	var caminho_arquivo: String = DIRETORIO_DECKS + nome_deck + ".json"
	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.WRITE)
	if arquivo == null:
		return false

	arquivo.store_string(JSON.stringify(dados_deck, "\t"))
	arquivo.close()
	return true


# =============================================================================
# CONTROLE DE TRANSIÇÃO DE ARQUIVOS PARA O DECK BUILDER
# =============================================================================

## Armazena temporariamente o dicionário do deck vindo do Gerenciador de Decks
var _deck_temporario_edicao: Dictionary = {}

## Chamado pelo gerenciador_decks.gd para definir qual deck abrir no construtor
func definir_deck_em_edicao(dados_deck: Dictionary) -> void:
	_deck_temporario_edicao = dados_deck

## Chamado pelo deck_builder.gd para pegar os dados armazenados e limpar a memória
func consumir_deck_em_edicao() -> Dictionary:
	var dados = _deck_temporario_edicao.duplicate(true)
	_deck_temporario_edicao.clear() # Limpa para não prender dados na memória
	return dados

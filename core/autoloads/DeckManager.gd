extends Node

# ==============================================================================
# DeckManager — Autoload Singleton (core/autoloads/DeckManager.gd)
# Responsável pela persistência de IDs e conversão para objetos CardResource.
# ==============================================================================

const DIRETORIO_DECKS    := "B:/GameDev/DINO TCG GAME/Dinogame/UsuariosTeste/"
const TAMANHO_DECK_VALIDO := 60

func _ready() -> void:
	_criar_diretorio_se_nao_existir()


func _criar_diretorio_se_nao_existir() -> void:
	if not DirAccess.dir_exists_absolute(DIRETORIO_DECKS):
		DirAccess.make_dir_recursive_absolute(DIRETORIO_DECKS)


func salvar_deck(nome_deck: String, lista_ids: Array[String]) -> bool:
	if nome_deck.strip_edges() == "": return false

	var caminho_arquivo := DIRETORIO_DECKS + nome_deck + ".json"
	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.WRITE)
	if arquivo == null: return false

	var dados_salvamento := {
		"nome": nome_deck,
		"cartas_ids": lista_ids
	}

	arquivo.store_string(JSON.stringify(dados_salvamento, "\t"))
	arquivo.close()
	return true


func carregar_lista_ids(nome_deck: String) -> Array:
	var caminho_arquivo := DIRETORIO_DECKS + nome_deck + ".json"
	if not FileAccess.file_exists(caminho_arquivo): return []

	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.READ)
	var texto := arquivo.get_as_text()
	arquivo.close()

	var json := JSON.new()
	if json.parse(texto) != OK: return []

	var dados = json.get_data()
	if typeof(dados) == TYPE_DICTIONARY and dados.has("cartas_ids"):
		return dados["cartas_ids"]
	return []

# ------------------------------------------------------------------------------
# NOVA FUNÇÃO DE CONVERSÃO PARA A ERA DOS RESOURCES
# ------------------------------------------------------------------------------
## Carrega o arquivo JSON do deck, pega os IDs salvos e devolve uma Array real cheia de CardResources tipados.
func carregar_deck_para_partida(nome_deck: String) -> Array[CardResource]:
	var lista_ids = carregar_lista_ids(nome_deck)
	var deck_de_resources: Array[CardResource] = []
	
	for id in lista_ids:
		# Pede ao CardDatabase a instância limpa do Resource nativo daquela carta
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
# FUNÇÕES ADICIONADAS PARA COMPATIBILIDADE COM A INTERFACE DE DECKS
# ==============================================================================

## Varre a pasta de testes para encontrar e retornar o nome de todos os arquivos de deck (.json)
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

# verifica qual é o deck ativo selecionado
func obter_deck_ativo() -> String:
	var lista := obter_lista_de_decks_salvos()
	for nome in lista:
		var dados := carregar_deck_completo(nome)
		if dados.get("ativo", false) == true:
			return nome
	return ""

## Lê o arquivo .json inteiro e retorna em formato de Dicionário para a UI extrair as informações
func carregar_deck_completo(nome_deck: String) -> Dictionary:
	var caminho_arquivo: String = DIRETORIO_DECKS + nome_deck + ".json"
	if not FileAccess.file_exists(caminho_arquivo): return {}

	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.READ)
	var texto := arquivo.get_as_text()
	arquivo.close()

	var json := JSON.new()
	if json.parse(texto) != OK: return {}

	var dados = json.get_data()
	if typeof(dados) == TYPE_DICTIONARY:
		return dados
	return {}


## Permite que a UI salve modificações diretas no dicionário do deck (como marcar o estado de "ativo")
func salvar_deck_completo(dados_deck: Dictionary) -> bool:
	var nome_deck: String = str(dados_deck.get("nome", "")).strip_edges()
	if nome_deck == "": return false

	var caminho_arquivo: String = DIRETORIO_DECKS + nome_deck + ".json"
	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.WRITE)
	if arquivo == null: return false

	arquivo.store_string(JSON.stringify(dados_deck, "\t"))
	arquivo.close()
	return true

extends Node

# ==============================================================================
# DeckManager — Autoload Singleton (core/autoloads/DeckManager.gd)
# Gerencia Estado Global de Decks e IO de Persistência em Disco.
# ==============================================================================

const DIRETORIO_DECKS := "user://decks/"

## Estado em runtime do deck sendo modificado pelas cenas de UI
var deck_em_edicao: DeckData = null


func _ready() -> void:
	_criar_diretorio_se_nao_existir()


func _criar_diretorio_se_nao_existir() -> void:
	if not DirAccess.dir_exists_absolute(DIRETORIO_DECKS):
		DirAccess.make_dir_recursive_absolute(DIRETORIO_DECKS)


func criar_novo_deck_para_edicao() -> void:
	deck_em_edicao = DeckData.new()
	deck_em_edicao.id = str(ResourceUID.create_id()) # Gera um ID único simples


func definir_deck_para_edicao(nome_deck: String) -> void:
	deck_em_edicao = carregar_deck(nome_deck)


func salvar_deck(deck_data: DeckData) -> bool:
	if deck_data.nome.strip_edges() == "":
		return false

	var caminho_arquivo: String = DIRETORIO_DECKS + deck_data.nome + ".json"
	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.WRITE)
	if arquivo == null:
		return false

	var json_string = JSON.stringify(deck_data.para_dicionario(), "\t")
	arquivo.store_string(json_string)
	arquivo.close()
	return true


func carregar_deck(nome_deck: String) -> DeckData:
	var deck := DeckData.new()
	var caminho_arquivo: String = DIRETORIO_DECKS + nome_deck + ".json"
	
	if not FileAccess.file_exists(caminho_arquivo):
		return deck

	var arquivo := FileAccess.open(caminho_arquivo, FileAccess.READ)
	var texto := arquivo.get_as_text()
	arquivo.close()

	var json := JSON.new()
	if json.parse(texto) == OK:
		var dados = json.get_data()
		if typeof(dados) == TYPE_DICTIONARY:
			deck.de_dicionario(dados)
			
	return deck


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


func obter_deck_ativo() -> String:
	var lista := obter_lista_de_decks_salvos()
	for nome in lista:
		var dados_json := _ler_json_bruto(nome)
		if dados_json.get("ativo", false) == true:
			return nome
	return ""


func definir_deck_ativo(id_alvo: String) -> void:
	var lista := obter_lista_de_decks_salvos()
	for nome in lista:
		var deck = carregar_deck(nome)
		var mudou = false
		
		if deck.ativo and deck.id != id_alvo:
			deck.ativo = false
			mudou = true
		elif not deck.ativo and deck.id == id_alvo:
			deck.ativo = true
			mudou = true
			
		if mudou:
			salvar_deck(deck)


func excluir_deck(nome_deck: String) -> bool:
	var caminho := DIRETORIO_DECKS + nome_deck + ".json"
	if FileAccess.file_exists(caminho):
		DirAccess.remove_absolute(caminho)
		return true
	return false


## Helper interno rápido para ler dados de verificação sem inflar instâncias completas
func _ler_json_bruto(nome_deck: String) -> Dictionary:
	var caminho := DIRETORIO_DECKS + nome_deck + ".json"
	if not FileAccess.file_exists(caminho): return {}
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	var json := JSON.new()
	if json.parse(arquivo.get_as_text()) == OK:
		return json.get_data() if typeof(json.get_data()) == TYPE_DICTIONARY else {}
	return {}

extends Node

# ==============================================================================
# CardDatabase — Autoload Singleton (core/autoloads/CardDatabase.gd)
# Único ponto de entrada para leitura de recursos nativos de cartas e habilidades.
# ==============================================================================

const PASTA_CARTAS := "res://data/cards/"
const PASTA_HABILIDADES := "res://data/abilities/"

# Dicionários principais estruturados na memória usando o tipo estrito de Resource
var cartas: Dictionary = {}      # Chave: String (ID) -> Valor: CardResource
var habilidades: Dictionary = {} # Chave: String (ID_Nome) -> Valor: AbilityResource

# Dicionários auxiliares para filtros rápidos da IA/Mecânicas de jogo
var cartas_por_cor: Dictionary = {}
var cartas_por_estagio: Dictionary = {}

func _ready() -> void:
	_carregar_bancos_dados()


func _carregar_bancos_dados() -> void:
	_carregar_habilidades_resources()
	_carregar_cartas_resources()


# Varre a pasta de habilidades e carrega todos os arquivos .tres
func _carregar_habilidades_resources() -> void:
	if not DirAccess.dir_exists_absolute(PASTA_HABILIDADES):
		push_warning("CardDatabase: Pasta de habilidades não encontrada: " + PASTA_HABILIDADES)
		return
		
	var dir := DirAccess.open(PASTA_HABILIDADES)
	dir.list_dir_begin()
	var nome_arquivo := dir.get_next()
	
	while nome_arquivo != "":
		if not dir.current_is_dir() and nome_arquivo.ends_with(".tres"):
			var caminho_completo := PASTA_HABILIDADES + nome_arquivo
			var ab_res := load(caminho_completo) as AbilityResource
			if ab_res:
				# Indexa pelo ID ou por uma chave combinada ID_Nome para busca exata
				var chave_habilidade = ab_res.id + "_" + ab_res.name.validate_filename()
				habilidades[chave_habilidade] = ab_res
				
		nome_arquivo = dir.get_next()
	print("CardDatabase: " + str(habilidades.size()) + " Habilidades carregadas com sucesso.")


# Varre a pasta de cartas e carrega todos os arquivos .tres dinamicamente
func _carregar_cartas_resources() -> void:
	if not DirAccess.dir_exists_absolute(PASTA_CARTAS):
		push_error("CardDatabase: Pasta de cartas não encontrada: " + PASTA_CARTAS)
		return
		
	var dir := DirAccess.open(PASTA_CARTAS)
	dir.list_dir_begin()
	var nome_arquivo := dir.get_next()
	
	while nome_arquivo != "":
		if not dir.current_is_dir() and nome_arquivo.ends_with(".tres"):
			var caminho_completo := PASTA_CARTAS + nome_arquivo
			var card_res := load(caminho_completo) as CardResource
			if card_res:
				cartas[card_res.id] = card_res
				_indexar_filtros_auxiliares(card_res)
				
		nome_arquivo = dir.get_next()
	print("CardDatabase: " + str(cartas.size()) + " Cartas carregadas com sucesso.")


func _indexar_filtros_auxiliares(card: CardResource) -> void:
	var cor := card.color.to_lower().strip_edges()
	var estagio := card.stage.to_lower().strip_edges()
	
	if cor != "":
		if not cartas_por_cor.has(cor): cartas_por_cor[cor] = []
		cartas_por_cor[cor].append(card)
		
	if estagio != "":
		if not cartas_por_estagio.has(estagio): cartas_por_estagio[estagio] = []
		cartas_por_estagio[estagio].append(card)

# -----------------------------------------------------------------------------
# API PÚBLICA ATUALIZADA (Retorna instâncias limpas ou referências seguras)
# -----------------------------------------------------------------------------

## Obtém o recurso puro e duplicado da carta para que modificações na partida não alterem o arquivo original
func obter_carta(id: String) -> CardResource:
	if cartas.has(id):
		return cartas[id].duplicate() as CardResource
	return null


func obter_catalogo_completo() -> Dictionary:
	return cartas


## Puxa o texto de UI corrigido da habilidade baseado no ID da carta e nome da habilidade
func obter_descricao_habilidade(id_carta: String, nome_habilidade: String) -> String:
	var chave = id_carta + "_" + nome_habilidade.validate_filename()
	if habilidades.has(chave):
		return habilidades[chave].text_ui
	return "Descrição de habilidade não encontrada."


func get_todas() -> Array:
	return cartas.values()


func get_por_cor(cor: String) -> Array:
	return cartas_por_cor.get(cor.to_lower(), [])


func get_por_estagio(estagio: String) -> Array:
	return cartas_por_estagio.get(estagio.to_lower(), [])

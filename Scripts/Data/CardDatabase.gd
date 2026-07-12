extends Node

# ==============================================================================
# CardDatabase — Autoload Singleton (core/autoloads/CardDatabase.gd)
# Único ponto de entrada para leitura de recursos nativos de cartas e habilidades.
# Suporta varredura recursiva de subpastas. Indexa CardResource (Animal) e
# EffectResource (Energia/Vestígio/Cataclismo/Território) na mesma passada,
# usando CardBaseResource para reconhecer qualquer um dos dois.
# ==============================================================================

const PASTA_CARTAS := "res://Resources/Cards/"
const PASTA_HABILIDADES := "res://Resources/Abilities/"

# Chave: String (ID) -> Valor: CardResource
var cartas: Dictionary = {}
# Chave: String (ID) -> Valor: EffectResource
var efeitos: Dictionary = {}
# Chave: String (ID_Nome) -> Valor: AbilityResource
var habilidades: Dictionary = {}

# Dicionários auxiliares para filtros rápidos (só se aplicam a CardResource,
# que é quem tem color/stage)
var cartas_por_cor: Dictionary = {}
var cartas_por_estagio: Dictionary = {}

func _ready() -> void:
	_carregar_bancos_dados()


func _carregar_bancos_dados() -> void:
	_carregar_habilidades_resources()
	_carregar_cartas_resources_recursivo(PASTA_CARTAS)
	print("📦 [CardDatabase] Inicialização concluída. Cartas: ", cartas.size(), " | Efeitos: ", efeitos.size(), " | Habilidades: ", habilidades.size())


# Varre a pasta de habilidades e carrega todos os arquivos .tres
func _carregar_habilidades_resources() -> void:
	if not DirAccess.dir_exists_absolute(PASTA_HABILIDADES):
		push_warning("CardDatabase: Pasta de habilidades não encontrada: " + PASTA_HABILIDADES)
		return

	var dir := DirAccess.open(PASTA_HABILIDADES)
	if dir:
		dir.list_dir_begin()
		var nome_arquivo := dir.get_next()

		while nome_arquivo != "":
			if not dir.current_is_dir() and nome_arquivo.contains(".tres"):
				var caminho_completo := PASTA_HABILIDADES + nome_arquivo
				var ab_res := load(caminho_completo) as AbilityResource
				if ab_res:
					var chave_habilidade = ab_res.name.validate_filename()
					habilidades[chave_habilidade] = ab_res

			nome_arquivo = dir.get_next()


# Varre a pasta de cartas e TODAS as suas subpastas de forma recursiva.
# Carrega como CardBaseResource (a classe comum) e distribui pro
# dicionário certo (cartas ou efeitos) de acordo com o tipo real do
# .tres — assim uma única varredura cobre Animal e Efeito.
func _carregar_cartas_resources_recursivo(caminho_pasta: String) -> void:
	if not DirAccess.dir_exists_absolute(caminho_pasta):
		push_error("CardDatabase: Diretório não encontrado: " + caminho_pasta)
		return

	var dir := DirAccess.open(caminho_pasta)
	if not dir:
		return

	dir.list_dir_begin()
	var nome_item := dir.get_next()

	while nome_item != "":
		if nome_item == "." or nome_item == "..":
			nome_item = dir.get_next()
			continue

		var caminho_completo = caminho_pasta + nome_item

		if dir.current_is_dir():
			var sub_pasta = caminho_completo if caminho_completo.ends_with("/") else caminho_completo + "/"
			_carregar_cartas_resources_recursivo(sub_pasta)
		else:
			if nome_item.contains(".tres"):
				_carregar_um_recurso(caminho_completo)

		nome_item = dir.get_next()


func _carregar_um_recurso(caminho_completo: String) -> void:
	var recurso := load(caminho_completo) as CardBaseResource

	if recurso == null:
		push_warning("CardDatabase: %s não é um CardBaseResource (CardResource/EffectResource) — ignorado." % caminho_completo)
		return

	if recurso.id.strip_edges() == "":
		push_error("CardDatabase: Carta ignorada por falta de ID em: " + caminho_completo)
		return

	if recurso is CardResource:
		cartas[recurso.id] = recurso
		_indexar_filtros_auxiliares(recurso)
	elif recurso is EffectResource:
		efeitos[recurso.id] = recurso
	else:
		push_warning("CardDatabase: tipo de CardBaseResource desconhecido em %s — ignorado." % caminho_completo)


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
# API PÚBLICA
# -----------------------------------------------------------------------------

func obter_carta(id: String) -> CardResource:
	if cartas.has(id):
		return cartas[id].duplicate() as CardResource
	return null


## Equivalente a obter_carta(), mas para cartas de Efeito (Energia,
## Vestígio, Cataclismo, Território).
func obter_efeito(id: String) -> EffectResource:
	if efeitos.has(id):
		return efeitos[id].duplicate() as EffectResource
	return null


## Busca por id em QUALQUER catálogo (cartas ou efeitos), sem o
## chamador precisar saber de antemão o tipo. Útil pra telas como o
## DeckBuilder, que lidam com Animal e Efeito ao mesmo tempo.
func obter_qualquer(id: String) -> CardBaseResource:
	if cartas.has(id):
		return cartas[id].duplicate() as CardBaseResource
	if efeitos.has(id):
		return efeitos[id].duplicate() as CardBaseResource
	return null


func obter_catalogo_completo() -> Dictionary:
	return cartas


func obter_catalogo_completo_efeitos() -> Dictionary:
	return efeitos


## Catálogo combinado (Animal + Efeito) — chave id, valor CardBaseResource.
## Os dois arquivos-fonte (animais_profissional/efeitos_profissional)
## usam uma faixa de id compartilhada e sem sobreposição, então não há
## risco de colisão de chave ao mesclar.
func obter_catalogo_completo_tudo() -> Dictionary:
	var tudo: Dictionary = {}
	tudo.merge(cartas)
	tudo.merge(efeitos)
	return tudo


func obter_descricao_habilidade(nome_habilidade: String) -> String:
	var chave_normalizada = normalizar(nome_habilidade)
	for chave in habilidades.keys():
		if normalizar(chave) == chave_normalizada:
			return habilidades[chave].text_ui
	return "Descrição de habilidade não encontrada."


func get_todas() -> Array:
	return cartas.values()


func get_por_cor(cor: String) -> Array:
	return cartas_por_cor.get(cor.to_lower(), [])


func get_por_estagio(estagio: String) -> Array:
	return cartas_por_estagio.get(estagio.to_lower(), [])


func normalizar(texto: String) -> String:
	return texto.strip_edges() \
			.to_lower() \
			.rstrip(".") \
			.replace("á", "a").replace("à", "a").replace("â", "a").replace("ã", "a") \
			.replace("é", "e").replace("ê", "e") \
			.replace("í", "i") \
			.replace("ó", "o").replace("õ", "o").replace("ô", "o") \
			.replace("ú", "u") \
			.replace("ç", "c")

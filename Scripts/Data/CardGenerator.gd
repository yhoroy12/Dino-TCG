extends Button
# Certifique-se de criar uma pasta vazia chamada "cards" dentro de res://data/ antes de rodar!
const OUTPUT_DIR = "res://data/cards/"

func _ready() -> void:
	# ATENÇÃO: Mude os caminhos abaixo para onde seus arquivos estão salvos no computador de fato,
	# ou use globalize_path se colocou na pasta do projeto.
	var caminho_animais = ProjectSettings.globalize_path("B:/GameDev/DINO TCG GAME/animais_profissional.csv")
	var caminho_efeitos = ProjectSettings.globalize_path("B:/GameDev/DINO TCG GAME/efeitos_profissional.csv")
	
	print("--- INICIANDO GERAÇÃO DE RESOURCES ---")
	_generate_from_csv(caminho_animais, true)
	_generate_from_csv(caminho_efeitos, false)
	print("--- PROCESSO CONCLUÍDO! VERIFIQUE A PASTA RES://DATA/CARDS/ ---")

func _generate_from_csv(absolute_path: String, is_animal: bool) -> void:
	if not FileAccess.file_exists(absolute_path):
		print("Arquivo não encontrado no sistema: ", absolute_path)
		return
		
	var file = FileAccess.open(absolute_path, FileAccess.READ)
	var headers = file.get_csv_line()
	
	while !file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < headers.size() or line[0] == "": 
			continue
			
		# Criamos uma nova instância limpa do nosso Resource personalizado
		var card = CardResource.new()
		
		# Preenche os dados mapeando a linha do CSV para as propriedades do Resource
		for i in range(headers.size()):
			var header_name = headers[i].strip_edges()
			var value = line[i].strip_edges()
			
			if header_name in card:
				if card.get(header_name) is int and value.is_valid_int():
					card.set(header_name, int(value))
				elif card.get(header_name) is float and value.is_valid_float():
					card.set(header_name, float(value))
				else:
					card.set(header_name, value)
					
		# Define o super_type correto para efeitos se não estiver definido
		if not is_animal and card.super_type == "":
			card.super_type = "vestigio" # Valor padrão seguro
			
		# Remove caracteres inválidos do nome para criar o nome do arquivo .tres
		var safe_name = card.name.validate_filename()
		if safe_name == "": safe_name = card.id
		
		var save_path = OUTPUT_DIR + card.id + "_" + safe_name + ".tres"
		
		# Salva o arquivo .tres nativo da Godot
		ResourceSaver.save(card, save_path)
		print("Criado: ", save_path)

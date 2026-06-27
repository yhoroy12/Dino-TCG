## Modelo de Dados
O Dino TCG utiliza dois tipos principais de Resources:


## Resources Principais

### CardResource

Representa qualquer carta do jogo.

Tipos suportados:

- animal
- vestigio
- cataclismo
- territorio
- energia

### AbilityResource

Representa habilidades reutilizáveis.

Cada habilidade define:

- gatilho (trigger)
- condição (condition)
- ação (action)
- alvo (target)
- quantidade (quantity)

As habilidades são interpretadas pelo BattleManager durante a partida.

---

## Fluxo de Execução

CardResource
↓
AbilityResource
↓
GameState
↓
BattleManager
↓
Resultado da partida

---

## Sistema Data Driven

As habilidades são definidas por parâmetros e não por scripts individuais.

Exemplo:

ao_sofrer_dano
↓
causar_dano
↓
20
↓
adversario ativo

O BattleManager interpreta esses dados durante a partida.

Isso permite criar novas habilidades sem escrever código.

---

## Responsabilidades

### CardDatabase

Responsável por:

* Carregar cartas
* Carregar habilidades
* Indexar recursos
* Fornecer acesso global aos dados

### DeckManager

Responsável por:

* Criar decks
* Salvar decks
* Carregar decks
* Validar regras de construção

### GameState

Responsável por:

* Estado da partida
* Jogadores
* Turnos
* Campo
* Pilhas
* Condições de vitória

### BattleManager

Responsável por:

* Resolver ataques
* Aplicar dano
* Aplicar condições
* Processar efeitos

---

## Princípios

* Single Source of Truth (GameState)
* Data Driven Design
* Separação entre Dados e Regras
* Interface sem lógica de jogo
* Reutilização de habilidades através de Resources

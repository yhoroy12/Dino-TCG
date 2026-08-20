# O Mapeamento da sua Arquitetura

  ┌─────────────────────────────────────────────────────────┐
  │                        UI / UX                          │
  │   (Mesa, Animações, Drag&Drop, Botões, Renderização)   │
  └────────────────────────────┬────────────────────────────┘
							   │ 1. Jogador tenta uma ação
							   ▼
  ┌─────────────────────────────────────────────────────────┐
  │                    MANAGERS (O Juiz)                    │
  │    (BattleManager, TurnManager, SetupManager, etc.)    │
  └──────────────┬──────────────────────────┬───────────────┘
				 │ 2. Pergunta / Aplica     │ 3. Atualiza
				 ▼                          ▼
  ┌───────────────────────────┐  ┌──────────────────────────┐
  │    SYSTEMS (Calculadora)  │  │   STATE (Ficha do Jogo)  │
  │  (Combat, Effect, Draw)   │  │ (GameState, PlayerState) │
  └───────────────────────────┘  └──────────────────────────┘

---

## 1. State (A Ficha do Jogo / Fonte da Verdade)

**O que é:** Os dados puros, sem nenhuma inteligência de código[cite: 1]. É o equivalente aos papéis, marcadores de vida e contadores impressos na mesa física[cite: 1].

**Comportamento:** `PlayerState`, `GameState`, `AnimalInstance`, `CardResource`[cite: 1].

**Regra de Ouro:** Não contêm regras de negócio complexas[cite: 1]. Guardam apenas números, listas (mão, deck, campo), strings e enumerações[cite: 1].

> ⚠️ **Regra Anti-Bug (Identificação em Runtime):** Nenhuma consulta do Estado para tomada de decisão em combate deve ser feita usando a propriedade estática de texto `CardResource.name`[cite: 1]. Toda referência a cartas ativas ou no banco em jogo utiliza obrigatoriamente a instância física única (`AnimalInstance`) ou seu identificador exclusivo (`instance_id`).

---

## 2. Systems (A Calculadora / Livro de Regras)

**O que é:** As ferramentas que o Juiz consulta[cite: 1]. São métodos estáticos (`static func`)[cite: 1].

**Comportamento:** `CombatSystem`, `DamageSystem`, `ConditionSystem`, `EffectSystem`, `EvolutionSystem`, `FoodSystem`, `KnockoutSystem`, `DrawSystem`, `DeckRulesSystem`, `WinConditionSystem`.

**Regra de Ouro:** Não guardam estado (não têm variáveis globais de saldo/vida) e não alteram o fluxo de jogo por conta própria[cite: 1]. Eles recebem um dado (ou referências diretas de `AnimalInstance`), fazem a conta/validação e devolvem uma resposta ou alteram a propriedade do dado recebido[cite: 1].

---

## 3. Managers (O Juiz de Mesa)

**O que é:** O cérebro orquestrador[cite: 1]. É o juiz físico que fica ao lado da mesa olhando tudo[cite: 1].

**Comportamento:** `BattleManager`, `TurnManager`, `SetupManager`, `RuleValidator`.

### Como trabalha (Exemplo de Fluxo de Combate):

1. O jogador (UI) diz: *"Quero atacar o Animal X com o Animal Y usando este Ataque"*[cite: 1].
2. O Juiz (`BattleManager`) checa o State chamando o `RuleValidator`:
   - Verifica se o jogador que declarou a ação é o dono do turno atual (`player_id`).
   - Garante que a carta alvo pertence ao oponente (`opponent_player_id`), evitando auto-ataques atrelados a cartas de mesmo nome.
   - Valida condições básicas do State (É o turno dele? Tem energia? Está dormindo?)[cite: 1].
3. O Juiz consulta os Systems especializados:
   - `CombatSystem.calcular_dano(atacante_instance, alvo_instance)`[cite: 1].
   - `ConditionSystem.rodar_moeda()`[cite: 1].
4. O Juiz aplica o dano no State através dos Systems:
   - `DamageSystem.aplicar_dano(alvo_instance, valor_dano)`[cite: 1].
5. O Juiz avisa a UI pelo EventBus ou resposta direta:
   - *"Ação validada! Toca a animação de ataque e atualiza o HP na tela"*[cite: 1].

---

## 4. UI/UX (A Mesa Visual e a Mão do Jogador)

**O que é:** A camada visual que o jogador humano interage (Cartas na tela, Drag & Drop, Botão de Passar Turno, Animações de Dano)[cite: 1].

**Regra de Ouro:** A UI nunca altera o State diretamente e nunca aplica dano[cite: 1]. Ela só envia intenções de ação (passando referências de zona e ID de jogador) para o `BattleManager` e escuta eventos (`EventBus`) para desenhar na tela o que o `BattleManager` aprovou[cite: 1].

---

## ARQUITETURA DA MESA

					┌─────────────────────────┐
					│     MesaDoTabuleiro     │
					│   (Interface / Visual)  │
					└────────────▲────────────┘
								 │
				   Notifica Mudanças / Renderiza
								 │
					┌────────────┴────────────┘
					│      BattleManager      │
					│     (Regras / Juiz)     │
					└▲───────────────────────▲┘
					 │                       │
	  Ações do Jogador 0           Ações do Jogador 1
					 │                       │
		   ┌─────────┴─────────┐   ┌─────────┴─────────┐
		   │  Jogador Humano   │   │  Fonte do Input:  │
		   │     (Mouse UI)    │   │ 🤖 AIBrain (IA)   │
		   └───────────────────┘   │        OU         │
								   │ 🌐 Peer (Network) │

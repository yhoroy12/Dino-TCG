O Mapeamento da sua Arquitetura
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
				 │ 2. Pergunta / Alica      │ 3. Atualiza
				 ▼                          ▼
  ┌───────────────────────────┐  ┌──────────────────────────┐
  │    SYSTEMS (Calculadora)  │  │   STATE (Ficha do Jogo)  │
  │  (Combat, Effect, Draw)   │  │ (GameState, PlayerState) │
  └───────────────────────────┘  └──────────────────────────┘
1. State (A Ficha do Jogo / Fonte da Verdade)
O que é: Os dados puros, sem nenhuma inteligência de código. É o equivalente aos papéis, marcadores de vida e contadores impressos na mesa física.

Comportamento: PlayerState, GameState, AnimalInstance, CardResource.

Regra de Ouro: Não contêm regras de negócio complexas. Guardam apenas números, listas (mao, deck, campo), strings e enumerações.

2. Systems (A Calculadora / Livro de Regras)
O que é: As ferramentas que o Juiz consulta. São métodos estáticos e puros (static func).

Comportamento: CombatSystem, EffectSystem, DrawSystem, ConditionSystem.

Regra de Ouro: Não guardam estado (não têm variáveis globais de saldo/vida) e não alteram fluxo de jogo por conta própria. Eles recebem um dado, fazem a conta/validação e devolvem uma resposta ou alteram a propriedade do dado recebido.

3. Managers (O Juiz de Mesa)
O que é: O cérebro orquestrador. É o juiz físico que fica ao lado da mesa olhando tudo.

Comportamento: BattleManager, TurnManager, SetupManager.

Como trabalha:

O jogador (UI) diz: "Quero atacar o Animal X com o Animal Y usando este Ataque".

O Juiz (BattleManager) checa o State (É o turno dele? Tem energia? Está dormindo?).

O Juiz consulta os Systems (CombatSystem.calcular_dano(), ConditionSystem.rodar_moeda()).

O Juiz aplica o dano no State (DamageSystem.aplicar_dano()).

O Juiz avisa a UI pelo EventBus ou resposta direta: "Ação validada! Toca a animação de ataque e atualiza o HP na tela".

4. UI/UX (A Mesa Visual e a Mão do Jogador)
O que é: A camada visual que o jogador humano interage (Cartas na tela, Drag & Drop, Botão de Passar Turno, Animações de Dano).

Regra de Ouro: A UI nunca altera o State diretamente e nunca aplica dano. Ela só envia intenções de ação para o BattleManager e escuta eventos (EventBus) para desenhar na tela o que o BattleManager aprovou.

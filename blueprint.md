# Bubble Tycoon - Blueprint Técnico

## Visão Geral
Jogo idle clicker desenvolvido em Flutter focado em satisfação tátil e progressão exponencial. O projeto utiliza uma arquitetura simples baseada em `setState` para gerenciamento de estado, otimizada para performance visual.

## UI/UX & Design System
- **Estilo Visual:** "Glassmorphism" (Vidro).
    - Uso intensivo de `Colors.withValues(alpha: ...)` para transparências.
    - `BackdropFilter` com `ImageFilter.blur` nas bolhas.
    - Gradientes lineares no fundo e radiais nas bolhas para efeito 3D.
- **Interação:**
    - `GestureDetector` com `onPanUpdate`: Permite o estouro contínuo ao arrastar o dedo (Swipe).
    - Cálculo matemático de grade `(dx / cellWidth)` para determinar o índice da bolha sob o toque.

## Lógica de Negócios

### 1. Economia
- **Fórmula de Nível:** Baseada na raiz quadrada dos ganhos totais para criar uma curva de dificuldade progressiva.
- **Inflação de Custos:** `custo * 1.5` a cada compra (crescimento exponencial).

### 2. Monetização (AdMob)
- **Banner:** Carregado no `initState`, exibido em um container fixo no rodapé. Possui tratamento de erro visual (placeholder cinza).
- **Interstitial:**
    - Carregamento antecipado (`preload`).
    - Gatilho: Disparado exclusivamente no evento `_onLevelUp`.
    - Recarregamento automático: Assim que um anúncio é fechado, o próximo já entra na fila de carregamento.

### 3. Persistência
- **Tech:** `shared_preferences`.
- **Trigger:** Salvamento automático a cada 10 segundos (`Timer.periodic`) ou ações críticas.
- **Dados:** Dinheiro, Ganhos Totais, Nível do Clique, Nível do Auto Bot.

## Estrutura de Arquivos
- **Main:** `lib/main.dart` (Código monolítico contendo a lógica do jogo, UI e widgets customizados para facilitar a manutenção no estágio MVP).
- **Assets:**
    - `assets/audio/`: pop.wav, cash.wav.
    - Fontes carregadas via pacote `google_fonts`.

## Status do Projeto
- **Versão:** Beta 1.0.
- **Próximos Passos:** Implementação real do IAP (Remover Anúncios) e publicação na Play Store.
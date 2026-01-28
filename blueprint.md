# Bubble Tycoon - Blueprint

## Visão Geral

Bubble Tycoon é um jogo idle clicker para dispositivos móveis, desenvolvido em Flutter. O objetivo é acumular dinheiro estourando bolhas. Os jogadores podem usar o dinheiro ganho para comprar upgrades que aumentam o valor de cada clique (estouro manual) ou geram renda passiva (estouros automáticos).

## Estilo e Design

- **UI:** A interface é limpa, moderna e focada na satisfação do usuário, com um layout claro e de fácil navegação.
- **Tema:** Utiliza `ThemeData` do Flutter com um `scaffoldBackgroundColor` em `Color(0xFFF0F4F8)` para um fundo suave e agradável.
- **Tipografia:** Emprega a fonte `VT323` do pacote `google_fonts` para dar uma sensação retrô e de arcade, reforçando a identidade do jogo.
- **Cores:** Paleta de cores baseada em tons de azul (`Colors.blue`) para as bolhas, com detalhes em verde (`Colors.green`) para o dinheiro e destaques em `Colors.blueAccent` e `Colors.orangeAccent` para os cartões de upgrade.
- **Animações:**
    - As bolhas possuem uma animação de "apertar" ao serem estouradas (`Transform.scale`) e uma mudança de estado visual (gradiente e ícone) para indicar que já foram estouradas e estão em tempo de recarga.
    - Os cartões de upgrade mudam de cor e estilo para indicar claramente quando o jogador tem dinheiro suficiente para a compra.

## Funcionalidades Implementadas (Versão Inicial)

### 1. Mecânica Principal (Clicker)
- Uma grade de 48 bolhas (`GridView`) é exibida na tela.
- Tocar em uma bolha (Widget `BubbleWidget`) a "estoura".
- Cada estouro concede ao jogador uma quantia de dinheiro (`money`) igual ao `clickValue`.
- Após ser estourada, a bolha se torna visualmente inativa e regenera após um tempo aleatório (entre 1.5 e 4 segundos).

### 2. Sistema de Moeda e Ganhos
- **Moeda Principal:** Dinheiro (variável `money` do tipo `double`).
- **Ganho por Clique:** O valor ganho por estouro (`clickValue`) começa em 1 e pode ser aumentado.
- **Ganho Automático:** O jogo possui um sistema de ganho passivo (`autoClickRate`) que adiciona dinheiro a cada segundo, mesmo sem interação do jogador.

### 3. Sistema de Upgrades
- Existem dois tipos de upgrades disponíveis na loja, na parte inferior da tela:
    - **Mãos Rápidas:** Aumenta o `clickValue`, tornando cada estouro manual mais lucrativo. O custo (`costClickUpgrade`) aumenta exponencialmente a cada nível.
    - **Máquina Auto:** Aumenta o `autoClickRate`, melhorando a renda passiva. O custo (`costAutoUpgrade`) também aumenta exponencialmente a cada nível.

### 4. Persistência de Dados
- O progresso do jogador é salvo automaticamente a cada 10 segundos.
- Utiliza o pacote `shared_preferences` para armazenar localmente as seguintes informações:
    - `money`: A quantidade de dinheiro atual.
    - `levelClick`: O nível do upgrade de clique.
    - `levelAuto`: O nível do upgrade automático.
- Ao iniciar o aplicativo, o progresso salvo é carregado, permitindo que os jogadores continuem de onde pararam.

### 5. Feedback Sensorial
- **Vibração:** Ao estourar uma bolha, o dispositivo vibra por um curto período (40ms) para fornecer um feedback tátil satisfatório. (Requer o pacote `vibration`).

### 6. Monetização (Placeholder)
- O layout inclui um espaço reservado (`Container`) na parte inferior para um banner de anúncio.
- O pacote `google_mobile_ads` foi integrado e inicializado, com a configuração de um ID de aplicativo de teste no `AndroidManifest.xml`, preparando o terreno para a futura implementação de anúncios reais.

## Plano para a Solicitação Atual

- **Status:** Concluído.
- **Passos Executados:**
    1. Adição das dependências `vibration`, `shared_preferences`, `google_fonts`, e `google_mobile_ads` via `flutter pub add`.
    2. Modificação do `android/app/src/main/AndroidManifest.xml` para incluir a permissão `android.permission.VIBRATE` e a meta-data do `APPLICATION_ID` do AdMob.
    3. Substituição do conteúdo de `lib/main.dart` pelo código completo do jogo "Bubble Tycoon".

# 🫧 Bubble Tycoon - Ultimate ASMR Clicker

![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.0%2B-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

**Bubble Tycoon** é um jogo *idle clicker* focado em **Satisfação Sensorial (ASMR)**. Desenvolvido em Flutter, ele utiliza técnicas avançadas de "Game Juice" para transformar toques simples em uma experiência viciante e relaxante.

## ✨ O "Game Juice" (Destaques Técnicos)

Esta versão (v1.2.1) implementa um motor sensorial robusto:

* 🔊 **Audio Pool Engine:** Sistema de polifonia com 5 canais de áudio simultâneos. Permite toques ultra-rápidos sem cortar ou engasgar o som de "pop".
* 🍬 **Visual 3D Glossy:** As bolhas não são imagens estáticas. São renderizadas via código (`CustomPainter` + `RadialGradient`) com simulação de luz, sombra e elasticidade.
* 🎉 **Partículas Físicas:** Sistema de confetes com gravidade e desaceleração que explodem a cada estouro.
* 💸 **Feedback Flutuante:** Números de ganhos (+$$$) que sobem e desaparecem (Fade/Slide transition) no local exato do toque.
* 📳 **Haptics Otimizado:** Vibração de baixa latência (`selectionClick`) para feedback tátil crocante.

## 🎮 Funcionalidades do Jogo

* **Mecânica Idle/Tycoon:** Acumule dinheiro e invista.
* **Upgrades:**
    * **Click Power:** Aumenta o valor do estouro manual.
    * **Auto Bot:** Renda passiva (funciona mesmo com o app fechado).
* **Sistema de Prestígio:** Resete seu progresso para ganhar multiplicadores permanentes (+20% por reset).
* **Monetização Híbrida:** Banner (AdMob) não intrusivo e recompensas opcionais.

## 🛠️ Tecnologias & Libraries

* **Framework:** Flutter & Dart (Null Safety).
* **Fonte:** [Fredoka](https://fonts.google.com/specimen/Fredoka) (Google Fonts) - Estilo arredondado e amigável.
* **Áudio:** `audioplayers` com modo `LowLatency`.
* **Armazenamento:** `shared_preferences` para persistência local segura.
* **Ads:** `google_mobile_ads` configurado para GDPR e políticas modernas.

## 📦 Instalação (Dev)

1.  Clone o repositório.
2.  Instale as dependências:
    ```bash
    flutter pub get
    ```
3.  Execute no emulador ou dispositivo físico:
    ```bash
    flutter run
    ```

---
*Desenvolvido por Felipe Galvão*

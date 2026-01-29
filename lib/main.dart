import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // APP ID PRODUÇÃO: ca-app-pub-1206696143040453~3450374275
  MobileAds.instance.initialize();
  runApp(const BubbleTycoonApp());
}

class BubbleTycoonApp extends StatelessWidget {
  const BubbleTycoonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bubble Tycoon Beta',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.vt323TextTheme(),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  double money = 0;
  double totalEarnings = 0;
  int clickValue = 1;
  double autoClickRate = 0;
  int levelClick = 1;
  int levelAuto = 0;
  double costClickUpgrade = 50;
  double costAutoUpgrade = 100;

  final AudioPlayer _sfxPlayer = AudioPlayer();
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // AdMob Interstitial
  InterstitialAd? _interstitialAd;

  final int _columns = 5;
  final int _rows = 9;
  final int _totalBubbles = 45;
  final List<GlobalKey<_BubbleWidgetState>> _bubbleKeys = List.generate(
    45,
    (_) => GlobalKey<_BubbleWidgetState>(),
  );

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _sfxPlayer.setReleaseMode(ReleaseMode.stop);

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (autoClickRate > 0) _addMoney(autoClickRate);
    });

    Timer.periodic(const Duration(seconds: 10), (timer) => _saveProgress());

    _initBannerAd();
    _loadInterstitialAd();
  }

  int get currentLevel {
    return (0.5 + sqrt(0.25 + (totalEarnings / 250))).floor();
  }

  double get currentLevelProgress {
    double xpInCurrentLevel =
        totalEarnings - (250.0 * currentLevel * (currentLevel - 1));
    double xpRequired = currentLevel * 500.0;
    return (xpInCurrentLevel / xpRequired).clamp(0.0, 1.0);
  }

  Color get levelColor {
    int lvl = currentLevel;
    if (lvl >= 20) return const Color(0xFF00FF41);
    if (lvl >= 10) return const Color(0xFFFFD700);
    if (lvl >= 5) return const Color(0xFFBC13FE);
    return Colors.cyan;
  }

  void _addMoney(double amount) {
    setState(() {
      int oldLevel = currentLevel;
      money += amount;
      totalEarnings += amount;
      if (currentLevel > oldLevel) _onLevelUp();
    });
  }

  void _onLevelUp() {
    // Exibe Anúncio Interstitial no Level Up
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      // O reload acontece automaticamente no callback 'onAdDismissedFullScreenContent'
    }

    _playSound('cash.wav');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: levelColor,
        behavior: SnackBarBehavior.floating,
        content: Text(
          "LEVEL UP! NÍVEL $currentLevel!",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  void _onPop() {
    _addMoney(clickValue.toDouble());
    _playSound('pop.wav');
    if (!kIsWeb) Vibration.vibrate(duration: 20);
  }

  void _playSound(String file) =>
      _sfxPlayer.play(AssetSource('audio/$file'), volume: 0.5);

  void _handleSwipe(Offset localPos, Size gridSize) {
    double cellWidth = gridSize.width / _columns;
    double cellHeight = gridSize.height / _rows;

    int col = (localPos.dx / cellWidth).floor();
    int row = (localPos.dy / cellHeight).floor();

    if (col >= 0 && col < _columns && row >= 0 && row < _rows) {
      int index = row * _columns + col;
      if (index >= 0 && index < _totalBubbles) {
        _bubbleKeys[index].currentState?.pop();
      }
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('money', money);
    await prefs.setDouble('totalEarnings', totalEarnings);
    await prefs.setInt('levelClick', levelClick);
    await prefs.setInt('levelAuto', levelAuto);
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      money = prefs.getDouble('money') ?? 0;
      totalEarnings = prefs.getDouble('totalEarnings') ?? 0;
      levelClick = prefs.getInt('levelClick') ?? 1;
      levelAuto = prefs.getInt('levelAuto') ?? 0;
      clickValue = levelClick;
      autoClickRate = levelAuto * 2.0;
      costClickUpgrade = (50 * pow(1.5, levelClick - 1)).toDouble();
      costAutoUpgrade = (100 * pow(1.5, levelAuto)).toDouble();
    });
  }

  void _initBannerAd() {
    _bannerAd = BannerAd(
      // ID TESTE BANNER: ca-app-pub-3940256099942544/6300978111
      // ID PRODUÇÃO BANNER: ca-app-pub-1206696143040453/1307826041
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdLoaded = true),
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      // ID TESTE INTERSTITIAL: ca-app-pub-3940256099942544/1033173712
      // ID PRODUÇÃO INTERSTITIAL: ca-app-pub-1206696143040453/9824210936
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                  _loadInterstitialAd(); // Carrega o próximo imediatamente
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  ad.dispose();
                  _loadInterstitialAd();
                },
              );
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0F7FA), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(
                value: currentLevelProgress,
                backgroundColor: Colors.black12,
                color: levelColor,
                minHeight: 12,
                borderRadius: BorderRadius.circular(6),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "LVL $currentLevel",
                          style: TextStyle(
                            fontSize: 22,
                            color: levelColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "\$${money.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "AUTO RATE",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          "+\$${autoClickRate.toStringAsFixed(0)}/s",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: levelColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onPanUpdate: (d) =>
                          _handleSwipe(d.localPosition, constraints.biggest),
                      onPanDown: (d) =>
                          _handleSwipe(d.localPosition, constraints.biggest),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(15),
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemCount: _totalBubbles,
                        itemBuilder: (context, index) => BubbleWidget(
                          key: _bubbleKeys[index],
                          onPop: _onPop,
                          activeColor: levelColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                height: 50,
                width: double.infinity,
                color: _isBannerAdLoaded
                    ? Colors.transparent
                    : Colors.grey.withValues(alpha: 0.1),
                alignment: Alignment.center,
                child: _isBannerAdLoaded
                    ? AdWidget(ad: _bannerAd!)
                    : const Text(
                        "ESPAÇO DO ANÚNCIO (Carregando...)",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
              ),
              _buildStore(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStore() {
    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 25),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          // Linha dos Upgrades Normais
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _UpgradeCard(
                    title: "CLICK POWER",
                    level: levelClick,
                    cost: costClickUpgrade,
                    icon: Icons.touch_app,
                    canBuy: money >= costClickUpgrade,
                    onTap: () {
                      if (money >= costClickUpgrade) {
                        _playSound('cash.wav');
                        setState(() {
                          money -= costClickUpgrade;
                          levelClick++;
                          clickValue++;
                          costClickUpgrade *= 1.5;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _UpgradeCard(
                    title: "AUTO BOT",
                    level: levelAuto,
                    cost: costAutoUpgrade,
                    icon: Icons.smart_toy,
                    canBuy: money >= costAutoUpgrade,
                    onTap: () {
                      if (money >= costAutoUpgrade) {
                        _playSound('cash.wav');
                        setState(() {
                          money -= costAutoUpgrade;
                          levelAuto++;
                          autoClickRate += 2;
                          costAutoUpgrade *= 1.5;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Botão "NO ADS" com visual de PROMOÇÃO
          SizedBox(
            width: double.infinity,
            height: 50, // Um pouco mais alto para caber o texto
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Promoção de lançamento em breve!"),
                  ),
                );
              },
              icon: const Icon(
                Icons.stars_rounded,
                color: Colors.yellowAccent,
                size: 28,
              ), // Ícone de estrela chama mais atenção
              // Trocamos o Text simples por uma Row para estilizar preços
              label: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "NO ADS! ",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  // Preço Antigo (Riscado)
                  Text(
                    "De U\$ 5,99 ",
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: 0.7,
                      ), // Um pouco transparente
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough, // O risco no meio
                      decorationColor: Colors.white70,
                      decorationThickness: 2.0,
                    ),
                  ),
                  // Preço Novo (Em destaque)
                  const Text(
                    " POR U\$ 2,79!",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900, // Extra negrito
                      fontSize: 18, // Maior
                      fontStyle: FontStyle.italic, // Itálico para dar dinamismo
                    ),
                  ),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors
                    .redAccent
                    .shade400, // Vermelho um pouco mais vibrante
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}

class BubbleWidget extends StatefulWidget {
  final VoidCallback onPop;
  final Color activeColor;
  const BubbleWidget({
    super.key,
    required this.onPop,
    required this.activeColor,
  });
  @override
  State<BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidget>
    with SingleTickerProviderStateMixin {
  bool isPopped = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  void pop() {
    if (isPopped) return;
    setState(() => isPopped = true);
    _controller.forward().then((_) => _controller.reverse());
    widget.onPop();
    Future.delayed(Duration(milliseconds: 2000 + Random().nextInt(2500)), () {
      if (mounted) setState(() => isPopped = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 0.8).animate(_controller),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isPopped ? 0 : 4,
            sigmaY: isPopped ? 0 : 4,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // CORRIGIDO AQUI: USANDO withValues()
              color: isPopped
                  ? Colors.black.withValues(alpha: 0.05)
                  : widget.activeColor.withValues(alpha: 0.25),
              border: Border.all(
                color: isPopped
                    ? Colors.black12
                    : Colors.white.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: isPopped
                ? null
                : Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment(-0.3, -0.4),
                        colors: [Colors.white70, Colors.transparent],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _UpgradeCard extends StatelessWidget {
  final String title;
  final int level;
  final double cost;
  final IconData icon;
  final bool canBuy;
  final VoidCallback onTap;

  const _UpgradeCard({
    required this.title,
    required this.level,
    required this.cost,
    required this.icon,
    required this.canBuy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          // CORRIGIDO AQUI
          color: canBuy ? Colors.white : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: canBuy ? Colors.blueAccent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: canBuy ? Colors.blueAccent : Colors.grey,
              size: 28,
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              "LVL $level",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: canBuy ? Colors.greenAccent : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "\$${cost.toStringAsFixed(0)}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

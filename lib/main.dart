
import 'dart:async';
import 'dart:math';
import 'dart:ui'; // Para ImageFilter

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:vibration/vibration.dart'; // Desativado para teste
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // MobileAds.instance.initialize(); // Desativado para teste
  runApp(const BubbleTycoonApp());
}

// --- PALETA DE CORES ---
class AppColors {
  static const Color primaryDark = Color(0xFF3D97AD); // Azul Petróleo
  static const Color primaryLight = Color(0xFF82C0CC); // Azul Suave
  static const Color bubbleShiny = Color(0xFF04E2FF); // Ciano Brilhante
  static const Color accentTeal = Color(0xFF09B8B2); // Detalhes
  static const Color moneyLime = Color(0xFFECFFB0); // Dinheiro (Destaque)
  static const Color bgWhite = Color(0xFFF0F4F8); // Fundo Suave
  static const Color bgGradientTop = Color(0xFFE0F7FA); // Azul muito claro para o topo
  static const Color bgGradientBottom = Color(0xFFF8F8F8); // Quase branco para o fundo
  static const Color glassBorder = Color(0x99FFFFFF); // Borda para Glassmorphism
}

class BubbleTycoonApp extends StatelessWidget {
  const BubbleTycoonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bubble Wrap Tycoon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bgWhite,
        textTheme: GoogleFonts.vt323TextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor: AppColors.primaryDark,
                displayColor: AppColors.primaryDark,
              ),
        ), // Fonte estilo Retro
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryDark),
        useMaterial3: true,
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
  // --- ESTADO ---
  double money = 0;
  int clickValue = 1;
  double autoClickRate = 0;
  int levelClick = 1;
  int levelAuto = 0;
  double costClickUpgrade = 50;
  double costAutoUpgrade = 100;

  Timer? _autoClickTimer;
  Timer? _saveTimer;
  final AudioPlayer _sfxPlayer = AudioPlayer(); // Instância única de AudioPlayer

  BannerAd? _bannerAd;
  final bool _isBannerAdLoaded = false;

  final List<GlobalKey<_BubbleWidgetState>> _bubbleKeys = List.generate(
      48, (_) => GlobalKey<_BubbleWidgetState>()); // Chaves para cada bolha

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProgress();

    _sfxPlayer.setReleaseMode(ReleaseMode.stop);

    _autoClickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (autoClickRate > 0) {
        setState(() => money += autoClickRate);
      }
    });

    _saveTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) => _saveProgress());

    // _loadBannerAd(); // Desativado para teste
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoClickTimer?.cancel();
    _saveTimer?.cancel();
    _sfxPlayer.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('money', money);
    await prefs.setInt('levelClick', levelClick);
    await prefs.setInt('levelAuto', levelAuto);
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      money = prefs.getDouble('money') ?? 0;
      levelClick = prefs.getInt('levelClick') ?? 1;
      levelAuto = prefs.getInt('levelAuto') ?? 0;

      clickValue = levelClick;
      autoClickRate = levelAuto * 2.0;
      costClickUpgrade = (50 * pow(1.5, levelClick - 1)).toDouble();
      costAutoUpgrade = (100 * pow(1.5, levelAuto)).toDouble();
    });
  }

  // --- ADS ---
  /*
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test Ad Unit ID
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _bannerAd = ad as BannerAd;
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          debugPrint('BannerAd failed to load: $err');
          setState(() {
            _isBannerAdLoaded = false;
          });
        },
      ),
    )..load();
  }
  */

  // --- AÇÕES ---
  void _playSound(String fileName) {
    _sfxPlayer.play(AssetSource('audio/$fileName'),
        mode: PlayerMode.lowLatency, volume: 0.7);
  }

  void _onBubblePop() {
    setState(() => money += clickValue);
    _playSound('pop.wav');

    /*
    Vibration.hasVibrator().then((has) {
      if (has == true) {
        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) {
          Vibration.vibrate(duration: 30);
        }
      }
    });
    */
  }

  void _buyUpgrade(bool isAuto) {
    double cost = isAuto ? costAutoUpgrade : costClickUpgrade;
    if (money >= cost) {
      _playSound('cash.wav');
      setState(() {
        money -= cost;
        if (isAuto) {
          levelAuto++;
          autoClickRate += 2;
          costAutoUpgrade *= 1.5;
        } else {
          levelClick++;
          clickValue++;
          costClickUpgrade *= 1.5;
        }
      });
      _saveProgress();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.star, color: AppColors.moneyLime),
              const SizedBox(width: 8),
              Text(
                'UPGRADE COMPRADO! +MOEDAS',
                style: GoogleFonts.vt323TextTheme()
                    .bodyMedium!
                    .copyWith(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _popBubbleAtLocalPosition(Offset localPosition) {
    // Itera sobre as bolhas para ver qual foi tocada
    for (var key in _bubbleKeys) {
      final RenderBox? renderBox =
          key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final Size size = renderBox.size;
        final Offset position = renderBox.localToGlobal(Offset.zero);

        final Rect bubbleRect = Rect.fromLTWH(
          position.dx,
          position.dy,
          size.width,
          size.height,
        );

        if (bubbleRect.contains(localPosition) &&
            key.currentState != null &&
            !key.currentState!.isPopped) {
          key.currentState?.popBubble();
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
                ],
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("BUBBLE TYCOON",
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    Row(children: [
                      const Icon(Icons.attach_money,
                          color: AppColors.accentTeal, size: 30),
                      Text(money.toStringAsFixed(0),
                          style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark)),
                    ]),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text("AUTO",
                        style: TextStyle(color: Colors.grey, fontSize: 10)),
                    Text("+\$${autoClickRate.toStringAsFixed(0)}/s",
                        style: const TextStyle(
                            fontSize: 18,
                            color: AppColors.accentTeal,
                            fontWeight: FontWeight.bold)),
                  ])
                ],
              ),
            ),

            // GRID DE BOLHAS (com Listener para arrastar)
            Expanded(
              child: Listener(
                onPointerMove: (event) {
                  _popBubbleAtLocalPosition(event.localPosition);
                },
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.bgGradientTop,
                        AppColors.bgGradientBottom
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(), // Impede rolagem
                    shrinkWrap: true, // Garante que o grid ocupe o espaço necessário
                    itemCount: _bubbleKeys.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (context, index) =>
                        BubbleWidget(key: _bubbleKeys[index], onPop: _onBubblePop),
                  ),
                ),
              ),
            ),

            // ESPAÇO ADMOB (Desativado para teste)
            /*
            if (_isBannerAdLoaded && _bannerAd != null)
              SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              )
            else
              Container(
                height: 50,
                color: Colors.grey[200],
                child: const Center(child: Text("Google AdMob Banner Area (Placeholder)")),
              ),
            */
            Container(
              height: 50,
              color: Colors.grey[200],
              child: const Center(
                  child: Text("Google AdMob Banner Area (Placeholder)")),

            // LOJA
            Container(
              height: 160,
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                      child: _UpgradeCard(
                    title: "CLICK POWER",
                    value: "+\$1",
                    level: levelClick,
                    cost: costClickUpgrade,
                    canBuy: money >= costClickUpgrade,
                    onTap: () => _buyUpgrade(false),
                    icon: Icons.touch_app,
                    color: AppColors.primaryDark,
                  )),
                  const SizedBox(width: 15),
                  Expanded(
                      child: _UpgradeCard(
                    title: "AUTO POPPER",
                    value: "+\$2/s",
                    level: levelAuto,
                    cost: costAutoUpgrade,
                    canBuy: money >= costAutoUpgrade,
                    onTap: () => _buyUpgrade(true),
                    icon: Icons.smart_toy,
                    color: AppColors.accentTeal,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET BOLHA (DESIGN GLASSMORPHISM) ---
class BubbleWidget extends StatefulWidget {
  final VoidCallback onPop;
  const BubbleWidget({super.key, required this.onPop});
  @override
  State<BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidget>
    with SingleTickerProviderStateMixin {
  bool isPopped = false;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 80),
        lowerBound: 0.0,
        upperBound: 0.2)
      ..addListener(() => setState(() {}));
  }

  void popBubble() {
    _pop();
  }

  void _pop() {
    if (isPopped) return;
    _ctrl.forward().then((_) => _ctrl.reverse());
    setState(() => isPopped = true);
    widget.onPop();
    Future.delayed(Duration(milliseconds: 2000 + Random().nextInt(3000)), () {
      if (mounted) setState(() => isPopped = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pop,
      child: Transform.scale(
        scale: 1.0 - _ctrl.value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPopped
                ? Colors.grey.shade300.withAlpha((255 * 0.5).round())
                : AppColors.primaryLight.withAlpha((255 * 0.3).round()),
            border: isPopped
                ? null
                : Border.all(color: AppColors.glassBorder, width: 1.5),
            boxShadow: isPopped
                ? []
                : [
                    BoxShadow(
                      color: AppColors.primaryDark.withAlpha((255 * 0.1).round()),
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.white.withAlpha((255 * 0.5).round()),
                      offset: const Offset(-2, -2),
                      blurRadius: 4,
                    ),
                  ],
          ),
          child: isPopped
              ? Center(
                  child: Icon(Icons.check, size: 12, color: Colors.grey.shade500))
              : ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, -0.3),
                          radius: 0.9,
                          colors: [
                            AppColors.bubbleShiny.withAlpha((255 * 0.7).round()),
                            AppColors.primaryLight.withAlpha((255 * 0.7).round()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// --- CARD UPGRADE ---
class _UpgradeCard extends StatelessWidget {
  final String title, value;
  final int level;
  final double cost;
  final bool canBuy;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  const _UpgradeCard({
    required this.title,
    required this.value,
    required this.level,
    required this.cost,
    required this.canBuy,
    required this.onTap,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: canBuy
          ? AppColors.moneyLime.withAlpha((255 * 0.8).round())
          : Colors.grey[100], // Usa a cor Lima para compra disponível
      borderRadius: BorderRadius.circular(16),
      elevation: canBuy ? 4 : 0,
      child: InkWell(
        onTap: canBuy ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: canBuy ? Colors.black87 : Colors.grey),
              const SizedBox(height: 5),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: canBuy ? Colors.black87 : Colors.grey)),
              Text(value,
                  style: TextStyle(
                      fontSize: 10,
                      color: canBuy ? Colors.black54 : Colors.grey)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: canBuy ? Colors.black12 : Colors.transparent,
                    borderRadius: BorderRadius.circular(10)),
                child: Text("\$${cost.toStringAsFixed(0)}",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: canBuy ? Colors.black : Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

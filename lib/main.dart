import 'dart:async';
import 'dart:math';
import 'dart:ui'; // Para ler o idioma do sistema

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const BubbleTycoonApp());
}

// --- GERENCIADOR DE TRADUÇÃO (VOLTOU!) ---
class TranslationManager {
  static String get languageCode {
    // Pega o idioma do celular (ex: 'pt', 'en', 'es')
    return PlatformDispatcher.instance.locale.languageCode;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Bubble Tycoon',
      'welcome_tip': 'Welcome! Tap bubbles to earn Dollars!',
      'tip_shop': 'Tip: Use your Dollars in the Shop to upgrade!',
      'tip_color': 'Almost there! New amazing color next level!',
      'tip_combo': 'Pro Tip: Drag your finger to pop many bubbles!',
      'level_up': 'LEVEL UP! Level @level reached!',
      'unlock_5': 'New color unlocks at level 5',
      'unlock_10': 'New color unlocks at level 10',
      'unlock_20': 'New color unlocks at level 20',
      'master': 'You are a Master!',
      'auto_bot': 'AUTO BOT',
      'click_power': 'CLICK POWER',
      'no_money': 'Not enough Dollars! Keep popping!',
      'ad_loading': 'ADVERTISEMENT',
    },
    'pt': {
      'app_title': 'Bubble Tycoon',
      'welcome_tip': 'Bem-vindo! Estoure bolhas para ganhar Dólares!',
      'tip_shop': 'Dica: Use seus Dólares na Loja para melhorar!',
      'tip_color': 'Quase lá! Nova cor incrível no próximo nível!',
      'tip_combo': 'Dica Pro: Arraste o dedo para estourar várias!',
      'level_up': 'SUBIU DE NÍVEL! Nível @level alcançado!',
      'unlock_5': 'Nova cor desbloqueia no nível 5',
      'unlock_10': 'Nova cor desbloqueia no nível 10',
      'unlock_20': 'Nova cor desbloqueia no nível 20',
      'master': 'Você é um Mestre!',
      'auto_bot': 'AUTO ROBÔ',
      'click_power': 'FORÇA DO CLICK',
      'no_money': 'Dólares insuficientes! Continue estourando!',
      'ad_loading': 'PUBLICIDADE',
    },
    'es': {
      'app_title': 'Bubble Tycoon',
      'welcome_tip': '¡Bienvenido! ¡Explota burbujas para ganar Dólares!',
      'tip_shop': 'Consejo: ¡Usa tus Dólares en la Tienda!',
      'tip_color': '¡Casi allí! ¡Nuevo color increíble pronto!',
      'tip_combo': 'Pro Tip: ¡Arrastra el dedo para explotar muchas!',
      'level_up': '¡NIVEL SUPERADO! ¡Nivel @level alcanzado!',
      'unlock_5': 'Nuevo color desbloqueado en el nivel 5',
      'unlock_10': 'Nuevo color desbloqueado en el nivel 10',
      'unlock_20': 'Nuevo color desbloqueado en el nivel 20',
      'master': '¡Eres un Maestro!',
      'auto_bot': 'AUTO BOT',
      'click_power': 'PODER DE CLICK',
      'no_money': '¡Dólares insuficientes! ¡Sigue explotando!',
      'ad_loading': 'PUBLICIDAD',
    }
  };

  static String translate(String key) {
    // Se não tiver o idioma, usa Inglês (en) como padrão
    String lang = _localizedValues.containsKey(languageCode) ? languageCode : 'en';
    return _localizedValues[lang]?[key] ?? key;
  }
}

class BubbleTycoonApp extends StatelessWidget {
  const BubbleTycoonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bubble Tycoon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.fredokaTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.light,
        ),
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
  // --- Variáveis de Estado ---
  double money = 0;
  double totalEarnings = 0;
  int clickValue = 1;
  double autoClickRate = 0;
  int levelClick = 1;
  int levelAuto = 0;
  double costClickUpgrade = 50;
  double costAutoUpgrade = 100;

  // --- Sistema ---
  final AudioPlayer _sfxPlayer = AudioPlayer();
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  InterstitialAd? _interstitialAd;
  Timer? _autoClickTimer;
  bool _hasShownFirstTip = false;

  // --- Grid ---
  final int _columns = 5;
  final int _rows = 7; 
  late int _totalBubbles;
  final double _gridPadding = 12.0;
  late List<GlobalKey<_BubbleWidgetState>> _bubbleKeys;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _totalBubbles = _columns * _rows;
    _bubbleKeys = List.generate(_totalBubbles, (_) => GlobalKey<_BubbleWidgetState>());
    
    _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    _loadProgress();
    
    _initBannerAd();
    _loadInterstitialAd();

    // Dica inicial
    Future.delayed(const Duration(seconds: 2), () {
      if (totalEarnings == 0) {
        _showTip(TranslationManager.translate('welcome_tip'));
        _hasShownFirstTip = true;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoClickTimer?.cancel();
    _sfxPlayer.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _autoClickTimer?.cancel();
      _saveProgress();
    } else if (state == AppLifecycleState.resumed) {
      _startAutoClicker();
    }
  }

  void _startAutoClicker() {
    _autoClickTimer?.cancel();
    if (autoClickRate > 0) {
      _autoClickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) _addMoney(autoClickRate);
      });
    }
  }

  // --- LÓGICA FINANCEIRA (TRAVADA EM DÓLAR $) ---
  String formatMoney(double value) {
    // Independente do país, sempre usa o símbolo $
    String suffix = "";
    double displayValue = value;

    if (value >= 1000000) {
      displayValue = value / 1000000;
      suffix = "M";
    } else if (value >= 1000) {
      displayValue = value / 1000;
      suffix = "k";
    }

    // Retorna fixo com $ na frente. Ex: $ 1.5k
    if (suffix.isEmpty) {
      return "\$ ${displayValue.toStringAsFixed(0)}";
    } else {
      // Usa . para decimais (padrão americano) ou , dependendo do gosto, 
      // mas mantendo o $ fixo. Vou deixar padrão US (ponto) pra ficar "Global".
      return "\$ ${displayValue.toStringAsFixed(1)}$suffix"; 
    }
  }

  int get currentLevel => (0.5 + sqrt(0.25 + (totalEarnings / 250))).floor();
  
  double get currentLevelProgress {
    double xpInCurrentLevel = totalEarnings - (250.0 * currentLevel * (currentLevel - 1));
    double xpRequired = currentLevel * 500.0;
    return (xpInCurrentLevel / xpRequired).clamp(0.0, 1.0);
  }

  Color get levelColor {
    int lvl = currentLevel;
    if (lvl >= 20) return const Color(0xFF00FF41); // Hacker Green
    if (lvl >= 10) return const Color(0xFFFFD700); // Gold
    if (lvl >= 5) return const Color(0xFFBC13FE);  // Purple
    return Colors.cyan;
  }

  String get nextGoalText {
    int lvl = currentLevel;
    if (lvl < 5) return TranslationManager.translate('unlock_5');
    if (lvl < 10) return TranslationManager.translate('unlock_10');
    if (lvl < 20) return TranslationManager.translate('unlock_20');
    return TranslationManager.translate('master');
  }

  void _addMoney(double amount) {
    if (!mounted) return;
    setState(() {
      int oldLevel = currentLevel;
      money += amount;
      totalEarnings += amount;
      
      if (currentLevel > oldLevel) {
        _onLevelUp();
      }
      
      if (!_hasShownFirstTip && money >= 40 && money < costClickUpgrade) {
        _showTip(TranslationManager.translate('tip_shop'));
        _hasShownFirstTip = true;
      }
       if (currentLevel == 4 || currentLevel == 9 || currentLevel == 19) {
        if (currentLevelProgress > 0.8) {
           _showTip(TranslationManager.translate('tip_color'));
        }
      }
    });
  }

  void _onLevelUp() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _loadInterstitialAd();
    }
    _playSound('cash.wav');
    String msg = TranslationManager.translate('level_up').replaceAll('@level', '$currentLevel');
    _showTip(msg, isImportant: true);
  }

  void _onPop() {
    _addMoney(clickValue.toDouble());
    _playSound('pop.wav');
    if (!kIsWeb) Vibration.vibrate(duration: 15);
    
    if (totalEarnings > 20 && totalEarnings < 30 && !_hasShownFirstTip) {
        _showTip(TranslationManager.translate('tip_combo'));
        _hasShownFirstTip = true;
    }
  }

  void _playSound(String file) => _sfxPlayer.play(AssetSource('audio/$file'), volume: 0.5);

  void _showTip(String message, {bool isImportant = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isImportant ? Icons.stars : Icons.lightbulb, color: Colors.yellowAccent),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: isImportant ? levelColor : Colors.blueGrey.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        duration: Duration(seconds: isImportant ? 4 : 3),
      ),
    );
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
      
      _startAutoClicker();
    });
  }

  void _initBannerAd() {
    _bannerAd = BannerAd(
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
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', 
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {},
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
                minHeight: 8,
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("LEVEL $currentLevel", style: TextStyle(fontSize: 18, color: levelColor, fontWeight: FontWeight.bold)),
                      Text(nextGoalText, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      Row(
                        children: [
                          Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 36),
                          const SizedBox(width: 5),
                          Text(formatMoney(money), 
                            style: TextStyle(
                              fontSize: 42, fontWeight: FontWeight.w900, height: 1,
                              color: Colors.blueGrey.shade900,
                            )
                          ),
                        ],
                      ),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(TranslationManager.translate('auto_bot'), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text("+${formatMoney(autoClickRate)}/s", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: levelColor)),
                    ]),
                  ],
                ),
              ),
              
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: _gridPadding),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _columns, 
                      mainAxisSpacing: _gridPadding, 
                      crossAxisSpacing: _gridPadding,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _totalBubbles,
                    itemBuilder: (context, index) => BubbleWidget(
                      key: _bubbleKeys[index], 
                      onPop: _onPop, 
                      activeColor: levelColor,
                    ),
                  ),
                ),
              ),

              Container(
                height: 60,
                width: double.infinity,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: _isBannerAdLoaded
                    ? AdWidget(ad: _bannerAd!)
                    : Text(TranslationManager.translate('ad_loading'), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
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
      height: 200, 
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: Offset(0, -3))],
      ),
      child: Row(
        children: [
          Expanded(child: _UpgradeCard(
            title: TranslationManager.translate('click_power'), level: levelClick, cost: costClickUpgrade, 
            icon: Icons.touch_app_rounded, canBuy: money >= costClickUpgrade, 
            formatCost: formatMoney,
            onTap: () {
              if (money >= costClickUpgrade) {
                _playSound('cash.wav');
                setState(() {
                  money -= costClickUpgrade;
                  levelClick++;
                  clickValue++;
                  costClickUpgrade *= 1.5;
                });
                _saveProgress();
              } else {
                 _showTip(TranslationManager.translate('no_money'));
              }
            },
          )),
          const SizedBox(width: 15),
          Expanded(child: _UpgradeCard(
            title: TranslationManager.translate('auto_bot'), level: levelAuto, cost: costAutoUpgrade, 
            icon: Icons.smart_toy_rounded, canBuy: money >= costAutoUpgrade,
            formatCost: formatMoney,
            onTap: () {
              if (money >= costAutoUpgrade) {
                _playSound('cash.wav');
                setState(() {
                  money -= costAutoUpgrade;
                  levelAuto++;
                  autoClickRate += 2;
                  costAutoUpgrade *= 1.5;
                  _startAutoClicker();
                });
                _saveProgress();
              } else {
                _showTip(TranslationManager.translate('no_money'));
              }
            },
          )),
        ],
      ),
    );
  }
}

class BubbleWidget extends StatefulWidget {
  final VoidCallback onPop;
  final Color activeColor;
  const BubbleWidget({super.key, required this.onPop, required this.activeColor});
  @override
  State<BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidget> with SingleTickerProviderStateMixin {
  bool isPopped = false;
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
  }

  void pop() {
    if (isPopped) return;
    setState(() => isPopped = true);
    _controller.forward().then((_) => _controller.reverse());
    widget.onPop();
    
    Future.delayed(Duration(milliseconds: 1500 + Random().nextInt(2000)), () {
      if (mounted) setState(() => isPopped = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: pop,
      onPanDown: (_) => pop(),
      onPanUpdate: (details) {
        RenderBox box = context.findRenderObject() as RenderBox;
        Offset localPosition = box.globalToLocal(details.globalPosition);
        if (box.paintBounds.contains(localPosition)) {
            pop();
        }
      },
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.85).animate(_controller),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPopped 
                ? Colors.grey.withOpacity(0.1) 
                : widget.activeColor.withOpacity(0.3),
            border: Border.all(
              color: isPopped ? Colors.transparent : widget.activeColor, 
              width: 2
            ),
            boxShadow: isPopped ? [] : [
              BoxShadow(
                color: widget.activeColor.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 2,
              )
            ],
          ),
          child: isPopped ? null : Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.4),
                colors: [Colors.white54, Colors.transparent],
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
  final String Function(double) formatCost;
  const _UpgradeCard({
    required this.title, required this.level, required this.cost, 
    required this.icon, required this.canBuy, required this.onTap,
    required this.formatCost,
  });
  @override
  Widget build(BuildContext context) {
    return Material( 
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: canBuy ? Colors.white : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: canBuy ? Colors.blueAccent : Colors.grey.shade300, width: 2),
            boxShadow: canBuy ? [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 5, offset: Offset(0, 2))] : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: canBuy ? Colors.blueAccent : Colors.grey, size: 32),
              const SizedBox(height: 5),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
              Text("Lv. $level", style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: canBuy ? Colors.green : Colors.grey, 
                  borderRadius: BorderRadius.circular(10)
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(formatCost(cost), 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

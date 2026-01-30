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
  MobileAds.instance.initialize();
  runApp(const BubbleTycoonApp());
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

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  // --- Variáveis de Estado do Jogo ---
  double money = 0;
  double totalEarnings = 0;
  int clickValue = 1;
  double autoClickRate = 0;
  int levelClick = 1;
  int levelAuto = 0;
  double costClickUpgrade = 50;
  double costAutoUpgrade = 100;
  
  bool _isNoAdsPurchased = false; 

  // --- Sistema e Recursos ---
  final AudioPlayer _sfxPlayer = AudioPlayer();
  
  // ADS
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;

  Timer? _autoClickTimer;
  bool _hasShownFirstTip = false;

  // --- Efeitos Visuais ---
  late AnimationController _coinRainController;
  List<CoinParticle> _coins = [];
  bool _isRaining = false;

  // --- Configuração da Grade ---
  final int _columns = 5;
  final int _rows = 6; 
  late int _totalBubbles;
  final double _gridPadding = 12.0;
  
  // Chaves globais para o Radar de Toque encontrar as bolhas
  late List<GlobalKey<_BubbleWidgetState>> _bubbleKeys;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _coinRainController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _coinRainController.addListener(() {
      setState(() {
        for (var coin in _coins) {
          coin.y += coin.speed;
          coin.rotation += 0.1;
        }
      });
    });
    _coinRainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isRaining = false;
          _coins.clear();
        });
      }
    });

    _totalBubbles = _columns * _rows;
    _bubbleKeys = List.generate(_totalBubbles, (_) => GlobalKey<_BubbleWidgetState>());

    _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    
    _loadProgress(); 

    Future.delayed(const Duration(seconds: 2), () {
      if (totalEarnings == 0) {
        _showTip("Bem-vindo! Deslize o dedo para estourar várias!");
        _hasShownFirstTip = true;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoClickTimer?.cancel();
    _coinRainController.dispose();
    _sfxPlayer.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _autoClickTimer?.cancel();
      _saveProgress();
    } else if (state == AppLifecycleState.resumed) {
      _startAutoClicker();
      _loadProgress();
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

  // --- Matemática do Jogo ---

  String formatMoney(double value) {
    if (value >= 1000000000) return "\$${(value / 1000000000).toStringAsFixed(2)}B";
    if (value >= 1000000) return "\$${(value / 1000000).toStringAsFixed(2)}M"; 
    if (value >= 1000) return "\$${(value / 1000).toStringAsFixed(1)}k";
    return value.toStringAsFixed(0);
  }

  // Fórmula Quadrática Estável
  int get currentLevel {
    return 1 + (sqrt(totalEarnings / 100)).floor();
  }

  double get currentLevelProgress {
    int lvl = currentLevel;
    double xpStart = 100.0 * pow(lvl - 1, 2);
    double xpEnd = 100.0 * pow(lvl, 2);
    
    double progress = (totalEarnings - xpStart) / (xpEnd - xpStart);
    return progress.clamp(0.0, 1.0);
  }

  Color get levelColor {
    double hue = (190 + (currentLevel * 15)) % 360;
    return HSVColor.fromAHSV(1.0, hue, 0.65, 0.95).toColor();
  }

  String get nextGoalText {
    return "Nível ${currentLevel + 1} em ${(100 - (currentLevelProgress * 100)).toStringAsFixed(0)}%";
  }

  void _addMoney(double amount) {
    if (!mounted) return;
    int oldLevel = currentLevel;
    setState(() {
      money += amount;
      totalEarnings += amount;
    });

    if (currentLevel > oldLevel) {
      _onLevelUp();
    }
    
    if (!_hasShownFirstTip && money >= 40 && money < costClickUpgrade) {
      _showTip("Dica: Vá na Loja e melhore seu clique!");
      _hasShownFirstTip = true;
    }
  }

  void _onLevelUp() {
    if (!_isNoAdsPurchased && _interstitialAd != null) {
      _interstitialAd!.show();
      _loadInterstitialAd();
    }
    _playSound('cash.wav');
    _triggerCoinRain(); 
    _showTip("LEVEL UP! Nível ${currentLevel} alcançado!", isImportant: true);
  }

  void _onPop() {
    _addMoney(clickValue.toDouble());
    _playSound('pop.wav');
    if (!kIsWeb) Vibration.vibrate(duration: 15);
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

  // --- RADAR DE TOQUE (SWIPE CORRIGIDO) ---
  // Essa função verifica onde o dedo está e estoura a bolha certa
  void _handleInput(PointerEvent details) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    // Varre todas as bolhas para ver qual está sob o dedo
    for (var key in _bubbleKeys) {
      if (key.currentContext != null) {
        final RenderBox bubbleBox = key.currentContext!.findRenderObject() as RenderBox;
        final Offset localPos = bubbleBox.globalToLocal(details.position);
        
        // Se o toque estiver dentro desta bolha
        if (bubbleBox.size.contains(localPos)) {
          key.currentState?.pop();
          break; // Já achou, para de procurar
        }
      }
    }
  }

  // --- EFEITO CHUVA DE MOEDAS ---
  void _triggerCoinRain() {
    setState(() {
      _isRaining = true;
      _coins = List.generate(30, (index) => CoinParticle());
    });
    _coinRainController.reset();
    _coinRainController.forward();
  }

  // --- Ganhos Offline ---
  void _checkOfflineEarnings(int lastSeenTime) {
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    int secondsPassed = ((currentTime - lastSeenTime) / 1000).floor();

    if (secondsPassed > 60 && autoClickRate > 0) {
      if (secondsPassed > 86400) secondsPassed = 86400;
      double earned = secondsPassed * autoClickRate;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Bem-vindo de volta!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time_filled, size: 50, color: Colors.orange),
              const SizedBox(height: 10),
              Text("Seu Auto Bot trabalhou por ${secondsPassed}s."),
              const SizedBox(height: 10),
              Text("+ ${formatMoney(earned)}", 
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                _addMoney(earned);
                _triggerCoinRain(); 
                Navigator.of(context).pop();
              },
              child: const Text("COLETAR TUDO"),
            )
          ],
        ),
      );
    }
  }

  void _showComingSoon() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Em Breve"),
        content: const Text("Esta funcionalidade estará disponível assim que o app for aprovado na Play Store!"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Entendi")),
        ],
      )
    );
  }

  // --- Persistência ---
  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('money', money);
    await prefs.setDouble('totalEarnings', totalEarnings);
    await prefs.setInt('levelClick', levelClick);
    await prefs.setInt('levelAuto', levelAuto);
    await prefs.setBool('no_ads', _isNoAdsPurchased);
    await prefs.setInt('last_seen', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      money = prefs.getDouble('money') ?? 0;
      totalEarnings = prefs.getDouble('totalEarnings') ?? 0;
      levelClick = prefs.getInt('levelClick') ?? 1;
      levelAuto = prefs.getInt('levelAuto') ?? 0;
      _isNoAdsPurchased = prefs.getBool('no_ads') ?? false;
      
      clickValue = levelClick;
      autoClickRate = levelAuto * 2.0;
      costClickUpgrade = (50 * pow(1.5, levelClick - 1)).toDouble();
      costAutoUpgrade = (100 * pow(1.5, levelAuto)).toDouble();
      
      _startAutoClicker();
    });

    if (!_isNoAdsPurchased) {
      _initBannerAd();
      _loadInterstitialAd();
      _loadRewardedAd();
    }

    int? lastSeen = prefs.getInt('last_seen');
    if (lastSeen != null) {
      Future.delayed(Duration(seconds: 1), () => _checkOfflineEarnings(lastSeen));
    }
  }

  // --- Configuração de Ads ---
  void _initBannerAd() {
    if (_isNoAdsPurchased) return;
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
    if (_isNoAdsPurchased) return;
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

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', 
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdReady = true;
          });
        },
        onAdFailedToLoad: (err) {
          setState(() => _isRewardedAdReady = false);
        },
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd == null || !_isRewardedAdReady) {
      _showTip("Carregando anúncio... Tente novamente em 5s.");
      _loadRewardedAd();
      return;
    }

    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      double bonus = (autoClickRate > 0) ? autoClickRate * 120 : 500;
      _addMoney(bonus);
      _playSound('cash.wav');
      _triggerCoinRain(); 
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Recompensa Recebida!"),
          content: Text("Você ganhou ${formatMoney(bonus)} moedas!"),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
        )
      );
    });

    _rewardedAd = null;
    _isRewardedAdReady = false;
    _loadRewardedAd();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: !_isNoAdsPurchased ? FloatingActionButton.extended(
        onPressed: _showRewardedAd,
        backgroundColor: _isRewardedAdReady ? Colors.pinkAccent : Colors.grey,
        icon: Icon(_isRewardedAdReady ? Icons.play_circle_filled : Icons.hourglass_empty, color: Colors.white),
        label: Text(_isRewardedAdReady ? "BÔNUS" : "CARREGANDO...", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ) : null,
      
      body: Stack(
        children: [
          Container(
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("NÍVEL $currentLevel", style: TextStyle(fontSize: 18, color: levelColor, fontWeight: FontWeight.bold)),
                          Text(nextGoalText, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          Row(
                            children: [
                              Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 32),
                              const SizedBox(width: 5),
                              Text(formatMoney(money), 
                                style: TextStyle(
                                  fontSize: 36, fontWeight: FontWeight.w900, height: 1,
                                  color: Colors.blueGrey.shade900,
                                )
                              ),
                            ],
                          ),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          const Text("AUTO BOT", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text("+${formatMoney(autoClickRate)}/s", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: levelColor)),
                        ]),
                      ],
                    ),
                  ),
                  
                  // LISTENER GLOBAL: É AQUI QUE A MÁGICA DO SWIPE ACONTECE
                  Expanded(
                    child: Listener(
                      // Captura o movimento e o toque inicial
                      onPointerMove: _handleInput,
                      onPointerDown: _handleInput,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: _gridPadding),
                        child: Center( 
                          child: AspectRatio(
                            aspectRatio: _columns / _rows,
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
                                // O onPop agora é chamado externamente, mas mantemos aqui para referência
                                activeColor: levelColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (!_isNoAdsPurchased)
                    Container(
                      height: 60,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: (_isBannerAdLoaded && _bannerAd != null)
                          ? AdWidget(ad: _bannerAd!)
                          : const Text("ESPAÇO PUBLICITÁRIO", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),

                  _buildStore(),
                ],
              ),
            ),
          ),

          if (_isRaining)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: CoinRainPainter(_coins),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStore() {
    return Container(
      height: 220, 
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: Offset(0, -3))],
      ),
      child: ListView( 
        scrollDirection: Axis.horizontal,
        children: [
          SizedBox(
            width: 120,
            child: _UpgradeCard(
              title: "CLICK POWER", level: levelClick, cost: costClickUpgrade, 
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
                   _showTip("Moedas insuficientes!");
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: _UpgradeCard(
              title: "AUTO BOT", level: levelAuto, cost: costAutoUpgrade, 
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
                  _showTip("Junte mais moedas!");
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          if (!_isNoAdsPurchased)
            GestureDetector(
              onTap: _showComingSoon,
              child: Container(
                width: 130,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.block, color: Colors.white, size: 30),
                          const SizedBox(height: 5),
                          const Text("NO ADS", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 5),
                          Text("USD \$9.99", style: TextStyle(color: Colors.white.withOpacity(0.7), decoration: TextDecoration.lineThrough, fontSize: 12)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                            child: const Text("USD \$2.79", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          )
                        ],
                      ),
                    ),
                    Positioned(
                      top: 10, right: 10,
                      child: Transform.rotate(
                        angle: 0.2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Text("-70%", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- WIDGET DA BOLHA SIMPLIFICADO ---
// Removemos o GestureDetector daqui. Quem controla agora é o pai (Listener).
class BubbleWidget extends StatefulWidget {
  final Color activeColor;
  const BubbleWidget({super.key, required this.activeColor});
  @override
  State<BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidget> with SingleTickerProviderStateMixin {
  bool isPopped = false;
  late AnimationController _controller;
  double _rotationAngle = 0; 

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _controller.addListener(() {
      setState(() {
        if (_controller.isAnimating) {
          _rotationAngle = (Random().nextDouble() - 0.5) * 0.2; 
        } else {
          _rotationAngle = 0;
        }
      });
    });
  }

  // Função chamada externamente pelo _handleInput do GameScreen
  void pop() {
    if (isPopped) return;
    setState(() => isPopped = true);
    _controller.forward().then((_) => _controller.reverse());
    
    // Chama o evento de som/dinheiro do pai de forma indireta? 
    // Não, precisamos que o Pai já tenha feito isso. 
    // O Radar (_handleInput) chama o pop, mas E A GRANA?
    // Correção: O Radar deve chamar a função de grana.
    // Melhor: O Radar chama o pop DAQUI, e aqui a gente avisa o pai.
    // Mas para simplificar e não precisar passar callback de novo:
    // Vamos fazer o Radar chamar o `_onPop` direto? Não temos acesso fácil.
    // SOLUÇÃO: O pai chama `key.currentState.pop()` E TAMBÉM `_onPop()`.
    // ESPERA! O `pop()` aqui é só visual.
    
    // Vamos ajustar: O `pop()` daqui só anima. O Pai conta a grana.
    // Não... o Radar no pai chama:
    // if (contains) { key.currentState.pop(); _onPop(); }
    
    // RESPIRAÇÃO AUTOMÁTICA: As bolhas precisam "reviver".
    Future.delayed(Duration(milliseconds: 1500 + Random().nextInt(2000)), () {
      if (mounted) setState(() => isPopped = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sem GestureDetector. Apenas visual.
    return Transform.rotate(
      angle: _rotationAngle,
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.7).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticIn)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isPopped 
              ? null 
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.9),
                    widget.activeColor.withOpacity(0.6),
                    widget.activeColor,
                  ],
                  stops: const [0.0, 0.4, 1.0]
                ),
            color: isPopped ? Colors.grey.withOpacity(0.05) : null,
            border: Border.all(
              color: isPopped ? Colors.transparent : widget.activeColor.withOpacity(0.3), 
              width: 1
            ),
            boxShadow: isPopped ? [] : [
              BoxShadow(
                color: widget.activeColor.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(4, 4) 
              ),
               BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 10,
                spreadRadius: -5,
                offset: const Offset(-4, -4) 
              )
            ],
          ),
          child: isPopped ? null : Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
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

// --- Componentes visuais ---
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: canBuy ? Colors.white : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: canBuy ? Colors.blueAccent : Colors.grey.shade300, width: 2),
            boxShadow: canBuy ? [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 5, offset: Offset(0, 2))] : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: canBuy ? Colors.blueAccent : Colors.grey, size: 28),
              const SizedBox(height: 5),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              Text("Lvl $level", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: canBuy ? Colors.green : Colors.grey, 
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(formatCost(cost), 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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

class CoinParticle {
  double x = Random().nextDouble() * 400; 
  double y = -50 - Random().nextDouble() * 200; 
  double speed = 5 + Random().nextDouble() * 10; 
  double rotation = Random().nextDouble() * 2 * pi;
  Color color = Colors.amber;
}

class CoinRainPainter extends CustomPainter {
  final List<CoinParticle> coins;
  CoinRainPainter(this.coins);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var coin in coins) {
      paint.color = coin.color;
      canvas.save();
      double drawX = coin.x % size.width;
      canvas.translate(drawX, coin.y);
      canvas.rotate(coin.rotation);
      canvas.drawCircle(Offset.zero, 12, paint);
      final borderPaint = Paint()..color = Colors.orange.shade900..style = PaintingStyle.stroke..strokeWidth = 2;
      canvas.drawCircle(Offset.zero, 12, borderPaint);
      TextPainter textPainter = TextPainter(
        text: const TextSpan(text: '\$', style: TextStyle(color: Colors.black45, fontSize: 14, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(-5, -8));
      canvas.restore();
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

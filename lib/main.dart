import 'dart:async';
import 'dart:math';
import 'dart:ui'; // Necessário para ler pixels se fosse avançado, mas aqui usamos para lerp

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
  
  // Variável VIP (IAP)
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

  // --- Efeitos Visuais (Chuva de Moedas) ---
  late AnimationController _coinRainController;
  List<CoinParticle> _coins = [];
  bool _isRaining = false;

  // --- Configuração da Grade ---
  final int _columns = 5;
  final int _rows = 7; 
  late int _totalBubbles;
  final double _gridPadding = 12.0;
  
  late List<GlobalKey<_BubbleWidgetState>> _bubbleKeys;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Configura controlador da chuva de moedas
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
    
    _loadProgress(); // Carrega dados primeiro para saber se tem NoAds

    Future.delayed(const Duration(seconds: 2), () {
      if (totalEarnings == 0) {
        _showTip("Bem-vindo! Toque nas bolhas para ganhar 'Moedas'!");
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

  // --- Matemática do Jogo (Ajustada para Infinito) ---

  String formatMoney(double value) {
    if (value >= 1000000000) return "\$${(value / 1000000000).toStringAsFixed(2)}B";
    if (value >= 1000000) return "\$${(value / 1000000).toStringAsFixed(2)}M"; 
    if (value >= 1000) return "\$${(value / 1000).toStringAsFixed(1)}k";
    return value.toStringAsFixed(0);
  }

  // Level Logarítmico
  int get currentLevel {
    if (totalEarnings < 100) return 1;
    return (log(totalEarnings) / log(1.6)).floor() - 5; 
  }

  double get currentLevelProgress {
    double xpForCurrent = pow(1.6, currentLevel + 5).toDouble();
    double xpForNext = pow(1.6, currentLevel + 6).toDouble();
    double progress = (totalEarnings - xpForCurrent) / (xpForNext - xpForCurrent);
    return progress.clamp(0.0, 1.0);
  }

  // SISTEMA DE CORES ETERNO (HSV)
  Color get levelColor {
    double hue = (180 + (currentLevel * 17)) % 360;
    return HSVColor.fromAHSV(1.0, hue, 0.8, 0.9).toColor();
  }

  String get nextGoalText {
    return "Próxima cor em ${(100 - (currentLevelProgress * 100)).toStringAsFixed(0)}%";
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
        _showTip("Dica: Vá na Loja e melhore seu clique!");
        _hasShownFirstTip = true;
      }
    });
  }

  void _onLevelUp() {
    // Só mostra AD se NÃO comprou o NoAds
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
    
    if (totalEarnings > 20 && totalEarnings < 30 && !_hasShownFirstTip) {
        _showTip("Dica Pro: Arraste o dedo para estourar rápido!");
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

  // --- EFEITO CHUVA DE MOEDAS ---
  void _triggerCoinRain() {
    setState(() {
      _isRaining = true;
      _coins = List.generate(30, (index) => CoinParticle());
    });
    _coinRainController.reset();
    _coinRainController.forward();
  }

  // --- Sistema de Ganhos Offline ---
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

  // --- SIMULAÇÃO DE COMPRA IAP ---
  void _buyNoAds() {
    // Aqui entraria a lógica real do in_app_purchase
    // Por enquanto, simulamos o sucesso.
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remover Anúncios?"),
        content: const Text("Deseja comprar a versão PRO por USD \$2.79?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isNoAdsPurchased = true;
                _bannerAd?.dispose(); // Remove banner imediatamente
                _bannerAd = null;
              });
              _saveProgress();
              _playSound('cash.wav');
              _triggerCoinRain();
              _showTip("Obrigado! Anúncios Removidos!", isImportant: true);
            }, 
            child: const Text("COMPRAR AGORA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
          ),
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
    await prefs.setBool('no_ads', _isNoAdsPurchased); // Salva status VIP
    await prefs.setInt('last_seen', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      money = prefs.getDouble('money') ?? 0;
      totalEarnings = prefs.getDouble('totalEarnings') ?? 0;
      levelClick = prefs.getInt('levelClick') ?? 1;
      levelAuto = prefs.getInt('levelAuto') ?? 0;
      _isNoAdsPurchased = prefs.getBool('no_ads') ?? false; // Carrega VIP
      
      clickValue = levelClick;
      autoClickRate = levelAuto * 2.0;
      costClickUpgrade = (50 * pow(1.5, levelClick - 1)).toDouble();
      costAutoUpgrade = (100 * pow(1.5, levelAuto)).toDouble();
      
      _startAutoClicker();
    });

    // Se não for VIP, carrega ads
    if (!_isNoAdsPurchased) {
      _initBannerAd();
      _loadInterstitialAd();
      _loadRewardedAd(); // Rewarded a gente mantém pq é opcional e dá dinheiro
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
    // Rewarded pode continuar existindo mesmo com NoAds, pois dá bônus?
    // Estrategicamente sim, mas se for VIP total, removemos. 
    // Vamos manter pra maximizar lucro, mas o botão some se não tiver carregado.
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
    if (_rewardedAd == null) {
      _showTip("Vídeo indisponível. Tente mais tarde.");
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
      floatingActionButton: _isRewardedAdReady ? FloatingActionButton.extended(
        onPressed: _showRewardedAd,
        backgroundColor: Colors.pinkAccent,
        icon: const Icon(Icons.play_circle_filled, color: Colors.white),
        label: const Text("BÔNUS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
      
      body: Stack(
        children: [
          // FUNDO E JOGO PRINCIPAL
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("NÍVEL $currentLevel", style: TextStyle(fontSize: 18, color: levelColor, fontWeight: FontWeight.bold)),
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
                          const Text("AUTO BOT", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
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

                  // ESPAÇO DO BANNER (Só mostra se não for VIP e estiver carregado)
                  if (!_isNoAdsPurchased && _isBannerAdLoaded && _bannerAd != null)
                    Container(
                      height: 60,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: AdWidget(ad: _bannerAd!),
                    ),

                  _buildStore(),
                ],
              ),
            ),
          ),

          // OVERLAY: CHUVA DE MOEDAS (Acima de tudo)
          if (_isRaining)
            Positioned.fill(
              child: IgnorePointer( // Deixa o clique passar para o jogo
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
      height: 220, // Aumentei um pouco para caber o IAP bonito
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: Offset(0, -3))],
      ),
      child: ListView( // Mudei para ListView horizontal para caber o card de IAP
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
          // CARD DE PROMOÇÃO "NO ADS"
          if (!_isNoAdsPurchased)
            GestureDetector(
              onTap: _buyNoAds,
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
                          // ANCHOR PRICING
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

// --- WIDGET DA BOLHA (Com Gradiente Diagonal e Física de Estouro) ---
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
  // Variável para a "tremida"
  double _rotationAngle = 0; 

  @override
  void initState() {
    super.initState();
    // Usei Curves.elasticIn para dar um "snap" satisfatório
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _controller.addListener(() {
      setState(() {
        // Gera um ângulo aleatório durante a animação para simular o "wobble"
        if (_controller.isAnimating) {
          _rotationAngle = (Random().nextDouble() - 0.5) * 0.2; // Pequena rotação
        } else {
          _rotationAngle = 0;
        }
      });
    });
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
      child: Transform.rotate(
        angle: _rotationAngle, // Aplica a tremida
        child: ScaleTransition(
          // Efeito elástico no scale
          scale: Tween(begin: 1.0, end: 0.7).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticIn)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200), // Transição de cor suave
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // LÓGICA DO GRADIENTE NA DIAGONAL
              gradient: isPopped 
                ? null 
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.activeColor, // Cor pura no canto
                      widget.activeColor.withOpacity(0.6), // Levemente mais claro
                      Colors.white.withOpacity(0.4), // Brilho (Highlight)
                    ],
                    stops: const [0.0, 0.7, 1.0]
                  ),
              color: isPopped ? Colors.grey.withOpacity(0.05) : null, // Se estourado, fica quase invisível
              border: Border.all(
                color: isPopped ? Colors.transparent : widget.activeColor.withOpacity(0.5), 
                width: 1
              ),
              boxShadow: isPopped ? [] : [
                BoxShadow(
                  color: widget.activeColor.withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: const Offset(2, 2) // Sombra deslocada para profundidade 3D
                )
              ],
            ),
            child: isPopped ? null : Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                // Um segundo gradiente radial sutil para dar o efeito de "bolha esférica"
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.4), // Ponto de luz deslocado
                  radius: 0.8,
                  colors: [Colors.white54, Colors.transparent],
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

// --- CARD DA LOJA ---
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

// --- CLASSES AUXILIARES PARA A CHUVA DE MOEDAS ---
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

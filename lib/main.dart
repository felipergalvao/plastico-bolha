import 'dart:async';
import 'dart:math';
import 'dart:ui'; 
import 'dart:io'; 

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

class TranslationManager {
  static String get languageCode {
    return PlatformDispatcher.instance.locale.languageCode;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Bubble Wrap Tycoon',
      'tip_slide': 'Slide your finger to pop multiple bubbles!',
      'tip_shop': 'Tip: Go to the Shop and upgrade your click!',
      'level_up': 'LEVEL UP!\nLevel @level reached!',
      'next_goal': 'Level @next in @percent%',
      'welcome_back': 'Welcome back!',
      'offline_work': 'Your Auto Bot worked for @seconds s.',
      'collect_all': 'COLLECT ALL',
      'coming_soon_title': 'Coming Soon',
      'coming_soon_msg': 'This feature will be available once the app is approved on Play Store!',
      'understood': 'Got it',
      'loading_ad': 'Loading ad... Try again in 5s.',
      'reward_title': 'Reward Received!',
      'reward_msg': 'You earned @amount coins!',
      'level': 'LEVEL',
      'auto_bot': 'AUTO BOT',
      'bonus': 'BONUS',
      'ad_space': 'ADVERTISEMENT SPACE',
      'click_power': 'CLICK POWER',
      'no_ads': 'NO ADS',
      'insufficient_funds': 'Insufficient funds!',
      'more_coins': 'Collect more coins!',
      'bonus_loading': '...',
    },
    'pt': {
      'app_title': 'Plástico Bolha Tycoon',
      'tip_slide': 'Deslize o dedo para estourar várias bolhas!',
      'tip_shop': 'Dica: Vá na Loja e melhore seu clique!',
      'level_up': 'LEVEL UP!\nNível @level alcançado!',
      'next_goal': 'Nível @next em @percent%',
      'welcome_back': 'Bem-vindo de volta!',
      'offline_work': 'Seu Auto Bot trabalhou por @seconds s.',
      'collect_all': 'COLETAR TUDO',
      'coming_soon_title': 'Em Breve',
      'coming_soon_msg': 'Esta funcionalidade estará disponível assim que o app for aprovado na Play Store!',
      'understood': 'Entendi',
      'loading_ad': 'Carregando anúncio... Tente novamente em 5s.',
      'reward_title': 'Recompensa Recebida!',
      'reward_msg': 'Você ganhou @amount moedas!',
      'level': 'NÍVEL',
      'auto_bot': 'AUTO ROBÔ',
      'bonus': 'BÔNUS',
      'ad_space': 'ESPAÇO PUBLICITÁRIO',
      'click_power': 'FORÇA DO CLICK',
      'no_ads': 'SEM ADS',
      'insufficient_funds': 'Moedas insuficientes!',
      'more_coins': 'Junte mais moedas!',
      'bonus_loading': '...',
    },
    'es': {
      'app_title': 'Plástico Burbuja Tycoon',
      'tip_slide': '¡Desliza el dedo para explotar burbujas!',
      'tip_shop': 'Consejo: ¡Ve a la Tienda y mejora tu clic!',
      'level_up': '¡NIVEL SUPERADO!\n¡Nivel @level alcanzado!',
      'next_goal': 'Nivel @next en @percent%',
      'welcome_back': '¡Bienvenido de nuevo!',
      'offline_work': 'Tu Auto Bot trabajó por @seconds s.',
      'collect_all': 'RECOGER TODO',
      'coming_soon_title': 'Próximamente',
      'coming_soon_msg': '¡Esta función estará disponible pronto!',
      'understood': 'Entendido',
      'loading_ad': 'Cargando anuncio... Intenta en 5s.',
      'reward_title': '¡Recompensa Recibida!',
      'reward_msg': '¡Ganaste @amount monedas!',
      'level': 'NIVEL',
      'auto_bot': 'AUTO BOT',
      'bonus': 'BONUS',
      'ad_space': 'ESPACIO PUBLICITARIO',
      'click_power': 'PODER CLICK',
      'no_ads': 'NO ADS',
      'insufficient_funds': '¡Fondos insuficientes!',
      'more_coins': '¡Consigue más monedas!',
      'bonus_loading': '...',
    }
  };

  static String translate(String key) {
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
      supportedLocales: const [
        Locale('en', ''),
        Locale('pt', ''),
        Locale('es', ''),
      ],
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
  // --- Variáveis de Estado ---
  double money = 0;
  double totalEarnings = 0;
  int clickValue = 1;
  double autoClickRate = 0;
  int levelClick = 1;
  int levelAuto = 0;
  double costClickUpgrade = 50;
  double costAutoUpgrade = 100;
  
  // --- PRESTIGE (Renascimento) ---
  int prestigeLevel = 0; 
  double get prestigeMultiplier => 1.0 + (prestigeLevel * 0.20); 
  
  bool _isNoAdsPurchased = false;
  
  // --- Ads ---
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
  bool _pendingAdTrigger = false;

  // --- AUDIO POOL OTIMIZADO ---
  final List<AudioPlayer> _sfxPool = [];
  int _poolIndex = 0;
  final int _poolSize = 10; 

  // --- Grid ---
  final int _columns = 5;
  final int _rows = 6; 
  late int _totalBubbles;
  final double _gridPadding = 8.0; 
  late List<GlobalKey<BubbleWidgetState>> _bubbleKeys;

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

    // --- INICIALIZA O POOL DE ÁUDIO ---
    for (int i = 0; i < _poolSize; i++) {
      final player = AudioPlayer();
      player.setPlayerMode(PlayerMode.lowLatency); 
      _sfxPool.add(player);
    }

    _totalBubbles = _columns * _rows;
    _bubbleKeys = List.generate(_totalBubbles, (_) => GlobalKey<BubbleWidgetState>());
    
    _initGameData();
    
    Future.delayed(const Duration(seconds: 2), () {
      if (totalEarnings == 0) {
        _showTip(TranslationManager.translate('tip_slide'));
        _hasShownFirstTip = true;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoClickTimer?.cancel();
    _coinRainController.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    
    for (var player in _sfxPool) {
      player.dispose();
    }
    
    super.dispose();
  }

  // --- NOVO MÉTODO: RESSUSCITA O SOM DEPOIS DO ANÚNCIO ---
  void _regenerateAudioPool() {
    // 1. Descarta os players antigos
    for (var player in _sfxPool) {
      try { player.dispose(); } catch (e) {
        // Ignora erros
      }
    }
    _sfxPool.clear(); 
    
    // 2. Cria novos players
    for (int i = 0; i < _poolSize; i++) {
      final player = AudioPlayer();
      player.setPlayerMode(PlayerMode.lowLatency);
      _sfxPool.add(player);
    }
    _poolIndex = 0;
  }

  // --- GERENCIAMENTO DE CICLO DE VIDA ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // O USUÁRIO SAIU (OU O ANÚNCIO ABRIU)
      _autoClickTimer?.cancel();
      Vibration.cancel(); 
      
      for (var player in _sfxPool) {
        player.stop();
      }
      
      _saveProgress(); 
    } else if (state == AppLifecycleState.resumed) {
      // O USUÁRIO VOLTOU (OU O ANÚNCIO FECHOU)
      _startAutoClicker();
      _checkOfflineEarningsOnResume();
      setState(() {});

      // --- A CORREÇÃO MÁGICA ---
      // Recria os sons que o anúncio "matou"
      _regenerateAudioPool();
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    super.didChangeLocales(locales);
    setState(() {});
  }

  void _startAutoClicker() {
    _autoClickTimer?.cancel();
    if (autoClickRate > 0) {
      _autoClickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) _addMoney(autoClickRate);
      });
    }
  }

  String formatMoney(double value) {
    if (value >= 1000000000) return "\$${(value / 1000000000).toStringAsFixed(2)}B";
    if (value >= 1000000) return "\$${(value / 1000000).toStringAsFixed(2)}M"; 
    if (value >= 1000) return "\$${(value / 1000).toStringAsFixed(1)}k";
    return "\$${value.toStringAsFixed(0)}";
  }

  int get currentLevel => 1 + (sqrt(totalEarnings / 100)).floor();
  double get currentLevelProgress {
    int lvl = currentLevel;
    double xpStart = 100.0 * pow(lvl - 1, 2);
    double xpEnd = 100.0 * pow(lvl, 2);
    return ((totalEarnings - xpStart) / (xpEnd - xpStart)).clamp(0.0, 1.0);
  }

  Color get levelColor {
    double hue = (190 + (currentLevel * 15)) % 360;
    return HSVColor.fromAHSV(1.0, hue, 0.65, 0.95).toColor();
  }

  String get nextGoalText {
    String percent = (100 - (currentLevelProgress * 100)).toStringAsFixed(0);
    return TranslationManager.translate('next_goal')
        .replaceAll('@next', '${currentLevel + 1}')
        .replaceAll('@percent', percent);
  }

  void _addMoney(double amount) {
    if (!mounted) return;
    int oldLevel = currentLevel;
    setState(() {
      double finalAmount = amount * prestigeMultiplier; 
      money += finalAmount;
      totalEarnings += finalAmount;
    });
    if (currentLevel > oldLevel) _onLevelUp();
    
    if (!_hasShownFirstTip && money >= 40 && money < costClickUpgrade) {
      _showTip(TranslationManager.translate('tip_shop'));
      _hasShownFirstTip = true;
    }
  }

  void _onLevelUp() {
    _saveProgress();
    _playSound('cash.wav');
    _triggerCoinRain(); 
    
    String msg = TranslationManager.translate('level_up').replaceAll('@level', '$currentLevel');
    _showTip(msg, isImportant: true);

    if (currentLevel == 10 && prestigeLevel == 0) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _showPrestigeDialog(); 
      });
    }

    if (!_isNoAdsPurchased) {
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) {
           _pendingAdTrigger = true; 
        }
      });
    }
  }

  void _onPop() {
    _addMoney(clickValue.toDouble());
    _playSound('pop.wav');
    
    if (!kIsWeb) {
      if (Vibration.hasVibrator() != null) {
         Vibration.vibrate(duration: 15);
      }
    }

    if (_pendingAdTrigger) {
      if (_interstitialAd != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
           if (mounted && _interstitialAd != null) { 
             _interstitialAd!.show();
             _loadInterstitialAd(); 
           }
        });
      }
      _pendingAdTrigger = false; 
    }
  }

  void _playSound(String file) async {
    if (_sfxPool.isEmpty) return; 

    final player = _sfxPool[_poolIndex];
    
    if (player.state == PlayerState.playing) {
      await player.stop();
    }
    
    player.play(AssetSource('audio/$file'), volume: 0.6);
    _poolIndex = (_poolIndex + 1) % _poolSize;
  }

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

  void _handleInput(PointerEvent details) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    for (var key in _bubbleKeys) {
      if (key.currentContext != null) {
        final RenderBox bubbleBox = key.currentContext!.findRenderObject() as RenderBox;
        final Offset localPos = bubbleBox.globalToLocal(details.position);
        if (bubbleBox.size.contains(localPos)) {
          if (key.currentState != null && !key.currentState!.isPopped) {
            key.currentState!.pop();
            _onPop(); 
          }
          break;
        }
      }
    }
  }

  void _triggerCoinRain() {
    setState(() {
      _isRaining = true;
      _coins = List.generate(30, (index) => CoinParticle());
    });
    _coinRainController.reset();
    _coinRainController.forward();
  }

  Future<void> _checkOfflineEarningsOnResume() async {
    final prefs = await SharedPreferences.getInstance();
    int? lastSeen = prefs.getInt('last_seen');
    if (lastSeen != null) _calculateAndShowOfflineEarnings(lastSeen);
  }

  void _calculateAndShowOfflineEarnings(int lastSeenTime) {
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    int secondsPassed = ((currentTime - lastSeenTime) / 1000).floor();

    if (secondsPassed > 60 && autoClickRate > 0) {
      if (secondsPassed > 86400) secondsPassed = 86400;
      double earned = secondsPassed * autoClickRate;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(TranslationManager.translate('welcome_back')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time_filled, size: 50, color: Colors.orange),
              const SizedBox(height: 10),
              Text(TranslationManager.translate('offline_work').replaceAll('@seconds', '$secondsPassed')),
              const SizedBox(height: 10),
              Text("+ ${formatMoney(earned)}", 
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                _addMoney(earned);
                _triggerCoinRain(); 
                Navigator.of(context).pop();
              },
              child: Text(TranslationManager.translate('collect_all')),
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
        title: Text(TranslationManager.translate('coming_soon_title')),
        content: Text(TranslationManager.translate('coming_soon_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(TranslationManager.translate('understood'))),
        ],
      )
    );
  }

  // --- PRESTIGE SYSTEM ---
    void _doPrestige() {
    _playSound('cash.wav');
    setState(() {
      prestigeLevel++;
      money = 0;
      totalEarnings = 0;
      clickValue = 1;
      autoClickRate = 0;
      levelClick = 1;
      levelAuto = 0;
      costClickUpgrade = 50;
      costAutoUpgrade = 100;
      _coins.clear();
      _isRaining = false;
    });
    _saveProgress();
    
    // CORREÇÃO: Usamos .round() para arredondar 19.99% para 20%
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("RENASCIMENTO! Bônus atual: ${((prestigeMultiplier-1)*100).round()}%"),
        backgroundColor: Colors.purpleAccent,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  void _showPrestigeDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("👑 RENASCIMENTO"),
        content: Text(
          "O jogo está muito difícil?\n\n"
          "Reinicie agora para ganhar um BÔNUS PERMANENTE de +20% em todos os ganhos!\n\n"
          // CORREÇÃO AQUI: .round() em vez de .toInt()
          "Atual: ${((prestigeMultiplier-1)*100).round()}%\n"
          "Após Renascer: ${((prestigeMultiplier-1)*100 + 20).round()}%"
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () {
              Navigator.pop(context);
              _doPrestige();
            },
            child: const Text("RENASCER AGORA", style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('money', money);
    await prefs.setDouble('totalEarnings', totalEarnings);
    await prefs.setInt('levelClick', levelClick);
    await prefs.setInt('levelAuto', levelAuto);
    await prefs.setBool('no_ads', _isNoAdsPurchased);
    await prefs.setInt('last_seen', DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt('prestigeLevel', prestigeLevel);
  }

  Future<void> _initGameData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      money = prefs.getDouble('money') ?? 0;
      totalEarnings = prefs.getDouble('totalEarnings') ?? 0;
      levelClick = prefs.getInt('levelClick') ?? 1;
      levelAuto = prefs.getInt('levelAuto') ?? 0;
      _isNoAdsPurchased = prefs.getBool('no_ads') ?? false;
      prestigeLevel = prefs.getInt('prestigeLevel') ?? 0;
      
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
      Future.delayed(const Duration(seconds: 1), () => _calculateAndShowOfflineEarnings(lastSeen));
    }

    // Checagem para veteranos
    if (currentLevel >= 10 && prestigeLevel == 0) {
      Future.delayed(const Duration(seconds: 3), () { 
        if (mounted) _showPrestigeDialog(); 
      });
    }
  }

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
      _showTip(TranslationManager.translate('loading_ad'));
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
          title: Text(TranslationManager.translate('reward_title')),
          content: Text(TranslationManager.translate('reward_msg').replaceAll('@amount', formatMoney(bonus))),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Row(
                              children: [
                                Text(
                                  "${TranslationManager.translate('level')} $currentLevel", 
                                  style: TextStyle(fontSize: 18, color: levelColor, fontWeight: FontWeight.bold)
                                ),
                                
                                // O BOTÃO COROA (Versão Nativa - À Prova de Falhas)
                                if (currentLevel >= 10)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: SizedBox(
                                      height: 28, 
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                            if (Vibration.hasVibrator() != null) Vibration.vibrate(duration: 50);
                                            _showPrestigeDialog();
                                        },
                                        icon: const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                                        label: const Text(
                                          "RESTART", 
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.purpleAccent,
                                          foregroundColor: Colors.white,
                                          elevation: 4,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap, 
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                  )
                              ],
                            ),

                            Text(nextGoalText, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          
                            Row(
                              children: [
                                const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 32),
                                const SizedBox(width: 5),
                                Text(formatMoney(money), 
                                  style: TextStyle(
                                    fontSize: 36, fontWeight: FontWeight.w900, height: 1,
                                    color: Colors.blueGrey.shade900,
                                  )
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          if (!_isNoAdsPurchased)
                            GestureDetector(
                              onTap: _showRewardedAd,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: _isRewardedAdReady ? Colors.pinkAccent : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: _isRewardedAdReady 
                                    ? [BoxShadow(color: Colors.pinkAccent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]
                                    : [],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.play_circle_fill, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isRewardedAdReady ? TranslationManager.translate('bonus') : TranslationManager.translate('bonus_loading'), 
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                          Text(TranslationManager.translate('auto_bot'), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text("+${formatMoney(autoClickRate)}/s", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: levelColor)),
                        ]),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: Listener(
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
                          : Text(TranslationManager.translate('ad_space'), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
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
      height: 170, 
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: Offset(0, -3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch, 
        children: [
          Expanded( 
            child: _UpgradeCard(
              title: TranslationManager.translate('click_power'),
              level: levelClick,
              cost: costClickUpgrade,
              icon: Icons.touch_app_rounded,
              canBuy: money >= costClickUpgrade,
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
                  _showTip(TranslationManager.translate('insufficient_funds'));
                }
              },
            ),
          ),
          
          const SizedBox(width: 8), 

          Expanded( 
            child: _UpgradeCard(
              title: TranslationManager.translate('auto_bot'),
              level: levelAuto,
              cost: costAutoUpgrade,
              icon: Icons.smart_toy_rounded,
              canBuy: money >= costAutoUpgrade,
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
                  _showTip(TranslationManager.translate('more_coins'));
                }
              },
            ),
          ),

          const SizedBox(width: 8),

          if (!_isNoAdsPurchased)
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showComingSoon,
                  borderRadius: BorderRadius.circular(20),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))
                      ],
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  children: [
                                    const Expanded(
                                      flex: 3, 
                                      child: FittedBox(child: Icon(Icons.block_flipped, color: Colors.white))
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          TranslationManager.translate('no_ads'),
                                          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const Spacer(flex: 1),

                              Expanded(
                                flex: 3,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.shade700,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const FittedBox(
                                    child: Padding(
                                      padding: EdgeInsets.all(2.0),
                                      child: Text(
                                        "\$2.79",
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10), topRight: Radius.circular(20)),
                            ),
                            child: const Text("-70%", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BubbleWidget extends StatefulWidget {
  final Color activeColor;
  const BubbleWidget({super.key, required this.activeColor});
  @override
  State<BubbleWidget> createState() => BubbleWidgetState();
}

class BubbleWidgetState extends State<BubbleWidget> with SingleTickerProviderStateMixin {
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

  void pop() {
    if (isPopped) return;
    setState(() => isPopped = true);
    _controller.forward().then((_) => _controller.reverse());
    Future.delayed(Duration(milliseconds: 1500 + Random().nextInt(2000)), () {
      if (mounted) setState(() => isPopped = false);
    });
  }

  @override
  Widget build(BuildContext context) {
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
              BoxShadow(color: widget.activeColor.withOpacity(0.2), blurRadius: 10, offset: const Offset(4, 4)),
              BoxShadow(color: Colors.white.withOpacity(0.8), blurRadius: 10, offset: const Offset(-4, -4))
            ],
          ),
          child: isPopped ? null : Container(decoration: const BoxDecoration(shape: BoxShape.circle)),
        ),
      ),
    );
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
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
    super.key, 
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: canBuy ? Colors.white : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: canBuy ? Colors.blueAccent : Colors.grey.shade300, width: 2),
            boxShadow: canBuy ? [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))] : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: FittedBox(
                  child: Icon(icon, color: canBuy ? Colors.blueAccent : Colors.grey),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(fit: BoxFit.scaleDown, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
                    FittedBox(fit: BoxFit.scaleDown, child: Text("Lvl $level", style: const TextStyle(color: Colors.grey))),
                  ],
                ),
              ),
              const Spacer(flex: 1),
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: canBuy ? Colors.green : Colors.grey, 
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: FittedBox( 
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(formatCost(cost), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
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

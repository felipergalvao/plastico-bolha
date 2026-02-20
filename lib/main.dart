import 'dart:async';
import 'dart:math';
import 'dart:ui'; 

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_soloud/flutter_soloud.dart'; 
import 'package:in_app_purchase/in_app_purchase.dart';

// VERSÃO 1.3.0 - IAP + ANDROID 15 FIXES

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  
  // --- CORREÇÃO PARA AVISOS DO GOOGLE PLAY (Android 15) ---
  // Habilita o modo ponta-a-ponta (Edge-to-Edge)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Define as barras do sistema como transparentes para cumprir as novas regras
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  final soloud = SoLoud.instance;
  await soloud.init();
  
  runApp(const BubbleTycoonApp());
}

class TranslationManager {
  static String get languageCode {
    return PlatformDispatcher.instance.locale.languageCode;
  }
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {'app_title': 'Bubble Wrap Tycoon', 'level_up': 'LEVEL UP!\nLevel @level reached!', 'welcome_back': 'Welcome back!', 'offline_work': 'Auto Bot earned:', 'collect_all': 'COLLECT', 'reward_title': 'Reward!', 'reward_msg': '+ @amount coins', 'level': 'LEVEL', 'auto_bot': 'AUTO BOT', 'bonus': 'BONUS', 'ad_space': 'AD SPACE', 'click_power': 'CLICK POWER', 'no_ads': 'NO ADS', 'restore': 'RESTORE', 'insufficient_funds': 'Need more coins!', 'loading_ad': 'Loading...', 'ad_error': 'No Video', 'next_goal': 'Next: @percent%', 'iap_error': 'Store Error'},
    'pt': {'app_title': 'Plástico Bolha Tycoon', 'level_up': 'LEVEL UP!\nNível @level!', 'welcome_back': 'Bem-vindo!', 'offline_work': 'Auto Bot lucrou:', 'collect_all': 'COLETAR', 'reward_title': 'Recompensa!', 'reward_msg': '+ @amount moedas', 'level': 'NÍVEL', 'auto_bot': 'AUTO ROBÔ', 'bonus': 'BÔNUS', 'ad_space': 'PUBLICIDADE', 'click_power': 'FORÇA CLICK', 'no_ads': 'SEM ADS', 'restore': 'RESTAURAR', 'insufficient_funds': 'Faltam moedas!', 'loading_ad': 'Carregando...', 'ad_error': 'Sem Vídeo', 'next_goal': 'Prox: @percent%', 'iap_error': 'Erro na Loja'},
    'es': {'app_title': 'Plástico Burbuja Tycoon', 'level_up': 'NIVEL SUPERADO!\nNivel @level!', 'welcome_back': '¡Hola de nuevo!', 'offline_work': 'Auto Bot ganó:', 'collect_all': 'RECOGER', 'reward_title': '¡Recompensa!', 'reward_msg': '+ @amount monedas', 'level': 'NIVEL', 'auto_bot': 'AUTO BOT', 'bonus': 'BONUS', 'ad_space': 'PUBLICIDAD', 'click_power': 'PODER CLICK', 'no_ads': 'NO ADS', 'restore': 'RESTAURAR', 'insufficient_funds': '¡Faltan monedas!', 'loading_ad': 'Cargando...', 'ad_error': 'Sin Video', 'next_goal': 'Prox: @percent%', 'iap_error': 'Error de Tienda'}
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
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.fredokaTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.light),
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
  // --- Game State ---
  double money = 0;
  double totalEarnings = 0;
  int clickValue = 1;
  double autoClickRate = 0;
  int levelClick = 1;
  int levelAuto = 0;
  double costClickUpgrade = 50;
  double costAutoUpgrade = 100;
  
  // --- PRESTIGE ---
  int prestigeLevel = 0; 
  double get prestigeMultiplier => 1.0 + (prestigeLevel * 0.20); 
  bool _showPrestigeMenu = false; 
  
  bool _isNoAdsPurchased = false; // Controle de Monetização
  
  // --- IAP (In-App Purchase) ---
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  
  final String _kNoAdsId = 'no_ads_permanent'; 
  final String _kTime1h = 'time_warp_1h';    // NOVO
  final String _kTime4h = 'time_warp_4h';    // NOVO
  final String _kTime12h = 'time_warp_12h';  // NOVO
  
  bool _isStoreAvailable = false;

  // --- Ads ---
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;
  
  Timer? _autoClickTimer;

  // --- Visuals ---
  late AnimationController _coinRainController;
  List<CoinParticle> _coins = [];
  bool _isRaining = false;
  bool _pendingAdTrigger = false;
  final List<FloatingTextModel> _floatingTexts = []; 

  // --- SOLOUD ENGINE ---
  AudioSource? _popSource;
  AudioSource? _cashSource;
  
  int _lastFeedbackTime = 0; 

  // --- Grid ---
  final int _columns = 5;
  final int _rows = 6; 
  late int _totalBubbles;
  late List<GlobalKey<BubbleWidgetState>> _bubbleKeys;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Configura o ouvinte de compras
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // Log silencioso
    });

    _initStore(); 

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
        setState(() { _isRaining = false; _coins.clear(); });
      }
    });

    _initAudio(); 

    _totalBubbles = _columns * _rows;
    _bubbleKeys = List.generate(_totalBubbles, (_) => GlobalKey<BubbleWidgetState>());
    
    _initGameData();
  }

  // --- IAP LOGIC ---
  Future<void> _initStore() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      setState(() => _isStoreAvailable = false);
      return;
    }
    setState(() => _isStoreAvailable = true);

    const Set<String> kIds = <String>{
      'no_ads_permanent', 
      'time_warp_1h', 
      'time_warp_4h', 
      'time_warp_12h'
    };
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(kIds);
    if (response.productDetails.isNotEmpty) {
      setState(() {
        _products = response.productDetails;
      });
    }
  }

  void _buyNoAds() {
    if (_products.isEmpty) {
        _inAppPurchase.restorePurchases(); // Fallback para restaurar
        return;
    }
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: _products.first);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _buyProduct(ProductDetails product) {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    if (product.id == _kNoAdsId) {
      // Produto Fixo (Non-Consumable)
      _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      // Salto no Tempo (Pode comprar várias vezes - Consumable)
      _inAppPurchase.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
    }
  }

  void _restorePurchases() {
    _inAppPurchase.restorePurchases();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Aguardando
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TranslationManager.translate('iap_error'))));
        } else if (purchaseDetails.status == PurchaseStatus.purchased || 
                   purchaseDetails.status == PurchaseStatus.restored) {
          _deliverProduct(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void _deliverProduct(PurchaseDetails purchaseDetails) {
    if (purchaseDetails.productID == _kNoAdsId) {
      setState(() {
        _isNoAdsPurchased = true;
        _bannerAd?.dispose(); 
        _bannerAd = null;
        _isBannerAdLoaded = false;
      });
      _saveProgress();
      _playCashSound();
      _triggerCoinRain();
    } 
    // NOVOS PACOTES DE TEMPO:
    else if (purchaseDetails.productID == _kTime1h) {
      _applyTimeWarp(1);
    } else if (purchaseDetails.productID == _kTime4h) {
      _applyTimeWarp(4);
    } else if (purchaseDetails.productID == _kTime12h) {
      _applyTimeWarp(12);
    }
  }

  // A MÁGICA DO SALTO NO TEMPO:
  void _applyTimeWarp(int hours) {
    // Se o cara comprou no nível 1 e não tem auto-bot, damos um valor base de $10/s
    double baseEarnings = autoClickRate > 0 ? autoClickRate : 10.0; 
    
    // Calcula: Ganho por segundo X Segundos em uma hora X Quantidade de Horas
    double totalEarned = baseEarnings * 3600 * hours; 
    
    _addMoney(totalEarned);
    _playCashSound();
    _triggerCoinRain();
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("+$hours Horas de Lucro! (+${formatMoney(totalEarned)})"),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
    ));
  }

  void _initAudio() async {
    try {
      _popSource = await SoLoud.instance.loadAsset('assets/audio/pop.wav');
      _cashSource = await SoLoud.instance.loadAsset('assets/audio/cash.wav');
    } catch (e) {
      debugPrint("Erro ao carregar audio: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription.cancel();
    _autoClickTimer?.cancel();
    _coinRainController.dispose();
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
      _checkOfflineEarningsOnResume();
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

  void _addMoney(double amount) {
    if (!mounted) return;
    int oldLevel = currentLevel;
    setState(() {
      double finalAmount = amount * prestigeMultiplier; 
      money += finalAmount;
      totalEarnings += finalAmount;
    });
    if (currentLevel > oldLevel) _onLevelUp();
  }

  void _onLevelUp() {
    _saveProgress();
    _playCashSound();
    _triggerCoinRain(); 
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(TranslationManager.translate('level_up').replaceAll('@level', '$currentLevel')),
      backgroundColor: levelColor,
      duration: const Duration(seconds: 2),
    ));

    if (currentLevel == 10 && prestigeLevel == 0) {
      setState(() {
        _showPrestigeMenu = true;
      });
    }

    if (!_isNoAdsPurchased) {
      if (_interstitialAd == null) _loadInterstitialAd();
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _pendingAdTrigger = true; 
      });
    }
  }

  void _onPop(Offset globalPosition) async {
    double earnings = clickValue.toDouble() * prestigeMultiplier;
    _addMoney(earnings);
    _spawnFloatingText(globalPosition, "+${formatMoney(earnings)}");
    
    if (_popSource != null) {
      var handle = await SoLoud.instance.play(_popSource!);
      SoLoud.instance.setRelativePlaySpeed(handle, 0.9 + Random().nextDouble() * 0.2);
    }
    
    int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFeedbackTime > 40) {
       _lastFeedbackTime = now;
       HapticFeedback.selectionClick(); 
    }

    if (!_isNoAdsPurchased && _pendingAdTrigger) {
      if (_interstitialAd != null) {
        _interstitialAd!.show();
        _pendingAdTrigger = false; 
      } else {
        _loadInterstitialAd(); 
      }
    }
  }

  void _spawnFloatingText(Offset pos, String text) {
    setState(() {
      _floatingTexts.add(FloatingTextModel(
        id: DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(100).toString(),
        position: pos,
        text: text,
        color: Colors.greenAccent.shade700
      ));
    });
  }

  void _playCashSound() {
     if (_cashSource != null) {
       SoLoud.instance.play(_cashSource!);
     }
  }

  void _handleInput(PointerEvent details) {
    if (_showPrestigeMenu) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    for (var key in _bubbleKeys) {
      if (key.currentContext != null) {
        final RenderBox bubbleBox = key.currentContext!.findRenderObject() as RenderBox;
        final Offset localPos = bubbleBox.globalToLocal(details.position);
        if (bubbleBox.size.contains(localPos)) {
          if (key.currentState != null && !key.currentState!.isPopped) {
            key.currentState!.pop();
            _onPop(details.position); 
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
    if (lastSeen != null) {
        int currentTime = DateTime.now().millisecondsSinceEpoch;
        int secondsPassed = ((currentTime - lastSeen) / 1000).floor();
        if (secondsPassed > 60 && autoClickRate > 0) {
            if (secondsPassed > 86400) secondsPassed = 86400;
            double earned = secondsPassed * autoClickRate;
            
            if (mounted) {
               _addMoney(earned);
               _triggerCoinRain();
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                 content: Text("${TranslationManager.translate('offline_work')} +${formatMoney(earned)}"),
                 backgroundColor: Colors.green,
                 duration: const Duration(seconds: 4),
               ));
            }
        }
    }
  }

  void _doPrestige() {
    if (_isNoAdsPurchased) {
      _executePrestigeReset();
      return;
    }

    if (_interstitialAd == null) _loadInterstitialAd();

    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          _executePrestigeReset(); 
          _loadInterstitialAd(); 
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _interstitialAd = null;
          _executePrestigeReset(); 
          _loadInterstitialAd();
        }
      );
      _interstitialAd!.show(); 
    } else {
      _executePrestigeReset();
    }
  }

  void _executePrestigeReset() {
    _playCashSound();
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
      _showPrestigeMenu = false; 
    });
    _saveProgress();
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
    
    if (currentLevel >= 10 && prestigeLevel == 0) {
      Future.delayed(const Duration(seconds: 2), () {
        if(mounted) setState(() => _showPrestigeMenu = true);
      });
    }
  }

  void _initBannerAd() {
    if (_isNoAdsPurchased) return;
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-1206696143040453/1307826041', 
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
    if (_interstitialAd != null) return; 

    InterstitialAd.load(
      adUnitId: 'ca-app-pub-1206696143040453/9824210936', 
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-1206696143040453/2605407915', 
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() { _rewardedAd = ad; _isRewardedAdReady = true; });
        },
        onAdFailedToLoad: (err) {
          setState(() => _isRewardedAdReady = false);
        },
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd == null || !_isRewardedAdReady) {
      _loadRewardedAd();
      return;
    }
    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      double bonus = (autoClickRate > 0) ? autoClickRate * 120 : 500;
      _addMoney(bonus);
      _playCashSound();
      _triggerCoinRain(); 
    });
    
    _rewardedAd = null;
    _isRewardedAdReady = false;
    _loadRewardedAd();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.transparent, // Pode ajudar no edge-to-edge
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFE0F7FA), Colors.white],
              ),
            ),
            child: SafeArea( // O SafeArea garante que o jogo não fique embaixo da câmera/bateria
              child: Column(
                children: [
                  LinearProgressIndicator(value: currentLevelProgress, backgroundColor: Colors.black12, color: levelColor, minHeight: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Row(children: [
                                Text("${TranslationManager.translate('level')} $currentLevel", style: TextStyle(fontSize: 18, color: levelColor, fontWeight: FontWeight.bold)),
                                if (currentLevel >= 10)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: SizedBox(
                                      height: 28, 
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                            HapticFeedback.mediumImpact();
                                            setState(() => _showPrestigeMenu = true);
                                        },
                                        icon: const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                                        label: const Text("RESTART", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                      ),
                                    ),
                                  )
                              ]),
                            Text(TranslationManager.translate('next_goal').replaceAll('@percent', (100 - (currentLevelProgress * 100)).toStringAsFixed(0)), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            Row(children: [
                                const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 32),
                                const SizedBox(width: 5),
                                Text(formatMoney(money), style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1, color: Colors.blueGrey.shade900)),
                              ]),
                          ],
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          // --- BOTÃO DA LOJA TURBO (Sempre visível) ---
                          GestureDetector(
                            onTap: _openTurboStore,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(20)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.rocket_launch, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text("TURBO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ]),
                            ),
                          ),
                          if (!_isNoAdsPurchased)
                            GestureDetector(
                              onTap: _showRewardedAd,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(color: _isRewardedAdReady ? Colors.pinkAccent : Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.play_circle_fill, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(_isRewardedAdReady ? TranslationManager.translate('bonus') : '...', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ]),
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
                        padding: const EdgeInsets.all(8),
                        child: Center( 
                          child: AspectRatio(
                            aspectRatio: _columns / _rows,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _columns, mainAxisSpacing: 8, crossAxisSpacing: 8),
                              itemCount: _totalBubbles,
                              itemBuilder: (context, index) => BubbleWidget(key: _bubbleKeys[index], activeColor: levelColor),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!_isNoAdsPurchased)
                    Container(
                      height: 60, width: double.infinity, color: Colors.grey.shade200, alignment: Alignment.center,
                      child: (_isBannerAdLoaded && _bannerAd != null) ? AdWidget(ad: _bannerAd!) : const Text("AD", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  _buildStore(),
                ],
              ),
            ),
          ),

          if (_isRaining) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: CoinRainPainter(_coins)))),
          
          ..._floatingTexts.map((ft) => FloatingTextWidget(
            key: ValueKey(ft.id),
            model: ft,
            onAnimationComplete: () {
              setState(() {
                _floatingTexts.removeWhere((item) => item.id == ft.id);
              });
            },
          )),

          if (_showPrestigeMenu)
            Container(
                color: Colors.black.withOpacity(0.8),
                width: double.infinity,
                height: double.infinity,
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(25.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, size: 50, color: Colors.purple),
                          const SizedBox(height: 15),
                          const Text("RENASCIMENTO", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          const Text("Reinicie seu progresso para ganhar\n+20% DE LUCRO ETERNO!", textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          Text("Atual: ${((prestigeMultiplier - 1)*100).round()}% -> Novo: ${((prestigeMultiplier - 1)*100 + 20).round()}%", 
                               style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 16)),
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () => setState(() => _showPrestigeMenu = false),
                                child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                                onPressed: _doPrestige,
                                child: const Text("RENASCER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                              )
                            ],
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

  Widget _buildStore() {
    String noAdsTitle = _isNoAdsPurchased ? "VIP" : TranslationManager.translate('no_ads');
    String noAdsPrice = _isNoAdsPurchased ? "DONE" : (_products.isNotEmpty ? _products.first.price : "\$2.79");
    VoidCallback noAdsAction = _isNoAdsPurchased ? () {} : _buyNoAds;
    if (!_isNoAdsPurchased && _products.isEmpty) {
        noAdsAction = _restorePurchases;
        noAdsPrice = TranslationManager.translate('restore');
    }

    return Container(
      height: 170, padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _UpgradeCard(title: "Click", level: levelClick, cost: costClickUpgrade, icon: Icons.touch_app, canBuy: money >= costClickUpgrade, formatCost: formatMoney, onTap: () {
             if (money >= costClickUpgrade) {
                _playCashSound();
                setState(() { money -= costClickUpgrade; levelClick++; clickValue++; costClickUpgrade *= 1.5; }); _saveProgress();
             }
          })),
          const SizedBox(width: 8),
          Expanded(child: _UpgradeCard(title: "Auto", level: levelAuto, cost: costAutoUpgrade, icon: Icons.smart_toy, canBuy: money >= costAutoUpgrade, formatCost: formatMoney, onTap: () {
             if (money >= costAutoUpgrade) {
                _playCashSound();
                setState(() { money -= costAutoUpgrade; levelAuto++; autoClickRate += 2; costAutoUpgrade *= 1.5; _startAutoClicker(); }); _saveProgress();
             }
          })),
          
          const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: noAdsAction,
                borderRadius: BorderRadius.circular(15),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: _isNoAdsPurchased 
                       ? const LinearGradient(colors: [Colors.green, Colors.lightGreen])
                       : const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8F00)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(flex: 6, child: Column(children: [
                              Expanded(flex: 3, child: FittedBox(child: Icon(_isNoAdsPurchased ? Icons.check_circle : Icons.block_flipped, color: Colors.white))),
                              Expanded(flex: 2, child: FittedBox(fit: BoxFit.scaleDown, child: Text(noAdsTitle, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)))),
                            ])),
                            const Spacer(flex: 1),
                            Expanded(flex: 3, child: Container(
                              width: double.infinity, 
                              decoration: BoxDecoration(color: _isNoAdsPurchased ? Colors.white24 : Colors.redAccent.shade700, borderRadius: BorderRadius.circular(8)), 
                              child: FittedBox(
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0), 
                                  child: Text(noAdsPrice, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                )
                              )
                            )),
                          ],
                        ),
                      ),
                      if (!_isNoAdsPurchased)
                        Positioned(top: 0, right: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10), topRight: Radius.circular(15))), child: const Text("-70%", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900))))
                    ],
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  void _openTurboStore() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("LOJA TURBO 🚀", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text("Compre horas de lucro instantâneo!", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildTimeWarpButton(_kTime1h, "Salto de 1 Hora", Icons.timer, Colors.blue),
              const SizedBox(height: 10),
              _buildTimeWarpButton(_kTime4h, "Salto de 4 Horas", Icons.speed, Colors.purple),
              const SizedBox(height: 10),
              _buildTimeWarpButton(_kTime12h, "Maleta de 12 Horas", Icons.work, Colors.orange),
              const SizedBox(height: 10),
            ]
          )
        );
      }
    );
  }

  Widget _buildTimeWarpButton(String id, String title, IconData icon, Color color) {
    try {
      final product = _products.firstWhere((p) => p.id == id);
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
        ),
        onPressed: () {
          Navigator.pop(context); // Fecha a janelinha
          _buyProduct(product);   // Abre o Google Pay
        },
        icon: Icon(icon, size: 28),
        label: Text("$title - ${product.price}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      );
    } catch (e) {
      // Se a loja não carregou ainda
      return const SizedBox.shrink(); 
    }
  }
}

class _UpgradeCard extends StatelessWidget {
  final String title; final int level; final double cost; final IconData icon; final bool canBuy; final VoidCallback onTap; final String Function(double) formatCost;
  const _UpgradeCard({required this.title, required this.level, required this.cost, required this.icon, required this.canBuy, required this.onTap, required this.formatCost});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap, 
        borderRadius: BorderRadius.circular(15), 
        child: Ink(
          decoration: BoxDecoration(
            color: canBuy ? Colors.white : Colors.grey.shade50, 
            borderRadius: BorderRadius.circular(15), 
            border: Border.all(color: canBuy ? Colors.blue : Colors.grey.shade300, width: 2),
            boxShadow: canBuy ? [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))] : [],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: canBuy ? Colors.blue : Colors.grey),
            Text("$title Lv$level", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: canBuy ? Colors.green : Colors.grey, borderRadius: BorderRadius.circular(5)), child: Text(formatCost(cost), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))
          ]),
        )
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
  List<ConfettiParticle> _confetti = [];
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _controller.addListener(() { 
      setState(() {
        for (var p in _confetti) {
          p.update();
        }
      }); 
    });
  }

  void pop() {
    if (isPopped) return;
    setState(() {
      isPopped = true;
      _spawnConfetti();
    });
    
    _controller.forward(from: 0.0).then((_) {
       Future.delayed(Duration(milliseconds: 2000 + Random().nextInt(3000)), () { 
         if (mounted) setState(() { isPopped = false; _confetti.clear(); }); 
       });
    });
  }
  
  void _spawnConfetti() {
    Color baseColor = widget.activeColor;
    List<Color> colors = [baseColor, Colors.white, Colors.amber, baseColor.withOpacity(0.5)];
    
    _confetti = List.generate(12, (index) {
       return ConfettiParticle(
         color: colors[index % colors.length],
         speed: 3.0 + Random().nextDouble() * 4.0,
         angle: (index / 12) * 2 * pi,
       );
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final double scale = isPopped ? 0.90 : 1.0;
    
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Transform.scale(
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isPopped 
                ? null 
                : RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    focal: const Alignment(-0.3, -0.3),
                    focalRadius: 0.1,
                    colors: [
                      Colors.white.withOpacity(0.9),
                      widget.activeColor.withOpacity(0.8),
                      widget.activeColor.withOpacity(1.0),
                      Colors.black.withOpacity(0.2),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
              color: isPopped ? Colors.grey.withOpacity(0.1) : null,
              boxShadow: isPopped ? [] : [
                  BoxShadow(color: widget.activeColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(4, 4)),
                  const BoxShadow(color: Colors.white60, blurRadius: 2, offset: Offset(-2, -2)),
              ],
              border: Border.all(
                  color: isPopped ? Colors.transparent : Colors.white.withOpacity(0.3), 
                  width: 1
              )
            ),
            child: isPopped ? null : Container(decoration: const BoxDecoration(shape: BoxShape.circle)),
          ),
        ),
        
        if (isPopped && _controller.isAnimating)
          CustomPaint(
            painter: ConfettiPainter(_confetti),
            size: const Size(100, 100),
          ),
      ],
    );
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
}

class ConfettiParticle {
  double x = 0;
  double y = 0;
  double opacity = 1.0;
  final Color color;
  double speed;
  final double angle;
  double gravity = 0.0;

  ConfettiParticle({required this.color, required this.speed, required this.angle});

  void update() {
    x += cos(angle) * speed;
    y += sin(angle) * speed;
    y += gravity;
    gravity += 0.5;
    speed *= 0.9; 
    opacity -= 0.03;
    if (opacity < 0) opacity = 0;
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  ConfettiPainter(this.particles);
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var p in particles) {
      if (p.opacity <= 0) continue;
      final paint = Paint()..color = p.color.withOpacity(p.opacity)..style = PaintingStyle.fill;
      canvas.drawCircle(center + Offset(p.x, p.y), 3, paint);
    }
  }
  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) => true;
}

class FloatingTextModel {
  final String id;
  final Offset position;
  final String text;
  final Color color;
  FloatingTextModel({required this.id, required this.position, required this.text, required this.color});
}

class FloatingTextWidget extends StatefulWidget {
  final FloatingTextModel model;
  final VoidCallback onAnimationComplete;
  const FloatingTextWidget({super.key, required this.model, required this.onAnimationComplete});

  @override
  State<FloatingTextWidget> createState() => _FloatingTextWidgetState();
}

class _FloatingTextWidgetState extends State<FloatingTextWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)));
    _offset = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -100)).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward().then((_) => widget.onAnimationComplete());
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.model.position.dx - 20, 
      top: widget.model.position.dy - 40,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: _offset.value,
            child: Opacity(
              opacity: _opacity.value,
              child: Text(
                widget.model.text,
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.w900, 
                  color: widget.model.color,
                  shadows: const [Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(1, 1))]
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
}

class CoinParticle { double x = Random().nextDouble() * 400; double y = -50 - Random().nextDouble() * 200; double speed = 5 + Random().nextDouble() * 10; double rotation = Random().nextDouble() * 2 * pi; }
class CoinRainPainter extends CustomPainter { final List<CoinParticle> coins; CoinRainPainter(this.coins); @override void paint(Canvas canvas, Size size) { final p = Paint()..color = Colors.amber; for (var c in coins) { canvas.drawCircle(Offset(c.x, c.y), 10, p); } } @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true; }

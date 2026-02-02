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
        // Fonte divertida e moderna para todo o app
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
  // --- Variáveis de Estado do Jogo ---
  double money = 0;
  double totalEarnings = 0;
  int clickValue = 1;
  double autoClickRate = 0;
  int levelClick = 1;
  int levelAuto = 0;
  double costClickUpgrade = 50;
  double costAutoUpgrade = 100;


  // --- Sistema e Recursos ---
  final AudioPlayer _sfxPlayer = AudioPlayer();
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  InterstitialAd? _interstitialAd;
  Timer? _autoClickTimer;
  bool _hasShownFirstTip = false; // Controle para o tutorial


  // --- Configuração da Grade ---
  // Reduzido para 7 linhas para garantir espaço pro Ad
  final int _columns = 5;
  final int _rows = 7; 
  late int _totalBubbles;
  final double _gridPadding = 12.0;
  
  // Chaves para controlar cada bolha individualmente
  late List<GlobalKey<_BubbleWidgetState>> _bubbleKeys;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _totalBubbles = _columns * _rows;
    _bubbleKeys = List.generate(_totalBubbles, (_) => GlobalKey<_BubbleWidgetState>());
    
    _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    _loadProgress(); // Carrega o jogo salvo
    
    _initBannerAd();
    _loadInterstitialAd();


    // Dica inicial após um pequeno delay
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
    _sfxPlayer.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }


  // --- Ciclo de Vida do App (Pausa o Bot quando sai) ---
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


  // --- Lógica do Jogo e Matemática ---


  String formatMoney(double value) {
    if (value >= 1000000) return "${(value / 1000000).toStringAsFixed(2)}M"; 
    if (value >= 1000) return "${(value / 1000).toStringAsFixed(1)}k";
    return value.toStringAsFixed(0);
  }


  int get currentLevel => (0.5 + sqrt(0.25 + (totalEarnings / 250))).floor();


  double get currentLevelProgress {
    double xpInCurrentLevel = totalEarnings - (250.0 * currentLevel * (currentLevel - 1));
    double xpRequired = currentLevel * 500.0;
    return (xpInCurrentLevel / xpRequired).clamp(0.0, 1.0);
  }


  Color get levelColor {
    int lvl = currentLevel;
    if (lvl >= 20) return const Color(0xFF00FF41); // Verde Hacker
    if (lvl >= 10) return const Color(0xFFFFD700); // Ouro
    if (lvl >= 5) return const Color(0xFFBC13FE);  // Roxo
    return Colors.cyan; 
  }


  String get nextGoalText {
    int lvl = currentLevel;
    if (lvl < 5) return "Será desbloqueado uma nova cor no nível 5";
    if (lvl < 10) return "Será desbloqueado uma nova cor no nível 10";
    if (lvl < 20) return "Será desbloqueado uma nova cor no nível 20";
    return "Você é um Mestre!";
  }


  void _addMoney(double amount) {
    if (!mounted) return;
    setState(() {
      int oldLevel = currentLevel;
      money += amount;
      totalEarnings += amount;
      
      // Verifica se subiu de nível
      if (currentLevel > oldLevel) {
        _onLevelUp();
      }
      
      // Dicas contextuais baseadas no dinheiro
      if (!_hasShownFirstTip && money >= 40 && money < costClickUpgrade) {
        _showTip("Dica: Use suas 'Moedas' na Loja para melhorar seu poder!");
        _hasShownFirstTip = true;
      }
       if (currentLevel == 4 || currentLevel == 9 || currentLevel == 19) {
        // Avisa antes de mudar de cor
        if (currentLevelProgress > 0.8) {
           _showTip("Quase lá! Nova cor incrível no próximo nível!");
        }
      }
    });
  }


  void _onLevelUp() {
    // Tenta mostrar anúncio interstitial ao passar de nível
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _loadInterstitialAd();
    }
    _playSound('cash.wav');
    _showTip("LEVEL UP! Nível ${currentLevel} alcançado!", isImportant: true);
  }


  // Função chamada pela bolha quando é estourada
  void _onPop() {
    _addMoney(clickValue.toDouble());
    _playSound('pop.wav');
    if (!kIsWeb) Vibration.vibrate(duration: 15);
    
    // Dica de deslizar depois de alguns cliques
    if (totalEarnings > 20 && totalEarnings < 30 && !_hasShownFirstTip) {
        _showTip("Dica Pro: Arraste o dedo para estourar várias seguidas!");
        _hasShownFirstTip = true;
    }
  }


  void _playSound(String file) => _sfxPlayer.play(AssetSource('audio/$file'), volume: 0.5);
  
  // Sistema de Dicas (Tutorial)
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


  // --- Persistência (Salvar/Carregar) ---


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
      
      // Recalcula custos e força
      clickValue = levelClick;
      autoClickRate = levelAuto * 2.0;
      costClickUpgrade = (50 * pow(1.5, levelClick - 1)).toDouble();
      costAutoUpgrade = (100 * pow(1.5, levelAuto)).toDouble();
      _startAutoClicker();
    });
  }


  // --- Configuração de Ads ---


  void _initBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // ID de Teste Google
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
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // ID de Teste Google
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
              // Barra de Progresso do Nível
              LinearProgressIndicator(
                value: currentLevelProgress,
                backgroundColor: Colors.black12,
                color: levelColor,
                minHeight: 8,
              ),
              
              // Cabeçalho de Informações
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
                          // Ícone de Moeda para deixar claro
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
              
              // --- ÁREA DO JOGO (GRID) ---
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: _gridPadding),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(), // Sem scroll
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _columns, 
                      mainAxisSpacing: _gridPadding, 
                      crossAxisSpacing: _gridPadding,
                      childAspectRatio: 1.0, // Bolhas perfeitamente redondas
                    ),
                    itemCount: _totalBubbles,
                    itemBuilder: (context, index) => BubbleWidget(
                      key: _bubbleKeys[index], 
                      onPop: _onPop, // Passa a função de ganhar dinheiro
                      activeColor: levelColor,
                    ),
                  ),
                ),
              ),


              // --- ESPAÇO DO BANNER (FIXO E SEPARADO) ---
              Container(
                height: 60, // Altura padrão do banner
                width: double.infinity,
                color: Colors.grey.shade200, // Cor de fundo para destacar do jogo
                alignment: Alignment.center,
                child: _isBannerAdLoaded
                    ? AdWidget(ad: _bannerAd!)
                    : const Text("PUBLICIDADE", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              ),


              // --- LOJA ---
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
            title: "FORÇA DO CLICK", level: levelClick, cost: costClickUpgrade, 
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
                 _showTip("Moedas insuficientes! Continue estourando!");
              }
            },
          )),
          const SizedBox(width: 15),
          Expanded(child: _UpgradeCard(
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
                _showTip("Precisa de mais moedas para o Robô!");
              }
            },
          )),
        ],
      ),
    );
  }
}


// --- WIDGET DA BOLHA (Com Detector de Toque Próprio) ---
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
    widget.onPop(); // Ganha o dinheiro
    
    // Respawn aleatório (1.5s a 3.5s)
    Future.delayed(Duration(milliseconds: 1500 + Random().nextInt(2000)), () {
      if (mounted) setState(() => isPopped = false);
    });
  }


  @override
  Widget build(BuildContext context) {
    // CORREÇÃO DO TOQUE: O GestureDetector é dono da bolha
    return GestureDetector(
      onTap: pop, // Clicou na bolha, chama o pop da bolha
      // Permite arrastar o dedo para estourar várias
      onPanDown: (_) => pop(),
      onPanUpdate: (details) {
        // Verifica se o dedo ainda está dentro da área da bolha
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


// --- CARD DA LOJA (Visual Melhorado) ---
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text("Nível $level", style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                    Icon(Icons.monetization_on, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
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
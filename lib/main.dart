
// --- INÍCIO DO CÓDIGO ---

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize(); // Inicializa AdMob
  runApp(const BubbleTycoonApp());
}

class BubbleTycoonApp extends StatelessWidget {
  const BubbleTycoonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bubble Wrap Tycoon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        // Fonte estilo Retro/Arcade
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
  // --- ESTADO DO JOGO ---
  double money = 0;
  int clickValue = 1;
  double autoClickRate = 0; // Dinheiro por segundo
  
  // Níveis dos Upgrades
  int levelClick = 1;
  int levelAuto = 0;

  // Custos Iniciais
  double costClickUpgrade = 50;
  double costAutoUpgrade = 100;

  Timer? _autoClickTimer;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProgress();
    
    // Timer do Auto-Clicker (roda a cada 1 segundo)
    _autoClickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (autoClickRate > 0) {
        setState(() {
          money += autoClickRate;
        });
      }
    });

    // Auto-Save a cada 10 segundos
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _saveProgress();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoClickTimer?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  // --- PERSISTÊNCIA DE DADOS ---
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
      
      // Recalcular stats baseados no nível
      clickValue = levelClick; 
      autoClickRate = levelAuto * 2.0; 
      
      // Recalcular custos (Fórmula exponencial: Base * 1.5^Nivel)
      costClickUpgrade = 50 * pow(1.5, levelClick - 1);
      costAutoUpgrade = 100 * pow(1.5, levelAuto);
    });
  }

  // --- LÓGICA DO JOGO ---
  void _onBubblePop() {
    setState(() {
      money += clickValue;
    });
    // Feedback Tátil
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 40); 
      }
    });
  }

  void _buyClickUpgrade() {
    if (money >= costClickUpgrade) {
      setState(() {
        money -= costClickUpgrade;
        levelClick++;
        clickValue++; 
        costClickUpgrade *= 1.5;
      });
      _saveProgress();
    }
  }

  void _buyAutoUpgrade() {
    if (money >= costAutoUpgrade) {
      setState(() {
        money -= costAutoUpgrade;
        levelAuto++;
        autoClickRate += 2;
        costAutoUpgrade *= 1.5;
      });
      _saveProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // HEADER (Dinheiro)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
                border: const Border(bottom: BorderSide(color: Colors.black12))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("BUBBLE TYCOON", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      Row(
                        children: [
                          const Icon(Icons.attach_money, color: Colors.green, size: 28),
                          Text(
                            money.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("GANHOS AUTO", style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                      Text(
                        "+\$${autoClickRate.toStringAsFixed(0)}/s",
                        style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                ],
              ),
            ),

            // GRID DE BOLHAS
            Expanded(
              child: Container(
                color: const Color(0xFFE8EEF5),
                padding: const EdgeInsets.all(10),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: 48, 
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    return BubbleWidget(onPop: _onBubblePop);
                  },
                ),
              ),
            ),

            // BANNER AD PLACEHOLDER (Espaço Visual)
            Container(
              height: 50,
              width: double.infinity,
              color: Colors.grey[200],
              child: const Center(child: Text("AdMob Banner Area (Test Mode)", style: TextStyle(color: Colors.grey))),
            ),

            // LOJA (Rodapé)
            Container(
              height: 160,
              padding: const EdgeInsets.all(15),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: _UpgradeCard(
                      title: "MÃOS RÁPIDAS",
                      desc: "Aumenta valor do clique",
                      value: "+1 \$/click",
                      level: levelClick,
                      cost: costClickUpgrade,
                      canBuy: money >= costClickUpgrade,
                      onTap: _buyClickUpgrade,
                      icon: Icons.touch_app,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _UpgradeCard(
                      title: "MÁQUINA AUTO",
                      desc: "Estoura bolhas sozinho",
                      value: "+2 \$/seg",
                      level: levelAuto,
                      cost: costAutoUpgrade,
                      canBuy: money >= costAutoUpgrade,
                      onTap: _buyAutoUpgrade,
                      icon: Icons.precision_manufacturing,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET DA BOLHA (Com Animação) ---
class BubbleWidget extends StatefulWidget {
  final VoidCallback onPop;
  const BubbleWidget({super.key, required this.onPop});

  @override
  State<BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidget> with SingleTickerProviderStateMixin {
  bool isPopped = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.15, // Encolhe 15%
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pop() {
    if (isPopped) return;

    // Animação de "apertar" (ida e volta rápida)
    _controller.forward().then((_) => _controller.reverse());

    setState(() {
      isPopped = true;
    });
    
    widget.onPop();

    // Regeneração
    Future.delayed(Duration(milliseconds: 1500 + Random().nextInt(2500)), () {
      if (mounted) {
        setState(() {
          isPopped = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pop,
      child: Transform.scale(
        scale: 1.0 - _controller.value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: isPopped
                ? []
                : [
                    BoxShadow(color: Colors.blue.withOpacity(0.4), offset: const Offset(3, 3), blurRadius: 5),
                    const BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 5),
                  ],
            gradient: isPopped
                ? RadialGradient(colors: [Colors.grey.shade300, Colors.grey.shade400])
                : RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    radius: 0.8,
                    colors: [Colors.blue.shade300, Colors.blue.shade600],
                  ),
          ),
          child: isPopped
              ? Center(child: Icon(Icons.check, size: 14, color: Colors.grey.shade500))
              : null,
        ),
      ),
    );
  }
}

// --- CARD DE UPGRADE ---
class _UpgradeCard extends StatelessWidget {
  final String title;
  final String desc;
  final String value;
  final int level;
  final double cost;
  final bool canBuy;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  const _UpgradeCard({
    required this.title, required this.desc, required this.value,
    required this.level, required this.cost, required this.canBuy,
    required this.onTap, required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: canBuy ? onTap : null,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: canBuy ? color : Colors.grey.shade200, width: 2),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: canBuy ? color : Colors.grey),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                    child: Text("Lvl $level", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 5),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: canBuy ? color : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "\$${cost.toStringAsFixed(0)}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- FIM DO CÓDIGO ---

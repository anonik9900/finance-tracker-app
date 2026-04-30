import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fl_chart/fl_chart.dart';

import 'models/transaction.dart';
import 'database/database_helper.dart';
import 'screens/add_transaction_screen.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  await notificationsPlugin.initialize(settings: settings);

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

//////////////////////////////////////////////////////////////
// 🍏 LIQUID GLASS (INSIGHT / GRAFICO)
//////////////////////////////////////////////////////////////

class LiquidGlass extends StatelessWidget {
  final Widget child;

  const LiquidGlass({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.transparent),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            top: -20,
            left: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// 💎 GLASS CARD LEGGERO (BUDGET)
//////////////////////////////////////////////////////////////

class LiquidGlassCard extends StatelessWidget {
  final Widget child;

  const LiquidGlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: Colors.transparent),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withOpacity(0.04),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// 🔥 PRESS EFFECT
//////////////////////////////////////////////////////////////

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const Pressable({required this.child, required this.onTap});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  double scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => scale = 0.96),
      onTapUp: (_) {
        setState(() => scale = 1);
        widget.onTap();
      },
      onTapCancel: () => setState(() => scale = 1),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// HOME
//////////////////////////////////////////////////////////////

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FinanceTransaction> transactions = [];

  Map<String, double> budgets = {
    'Food': 200,
    'Trasporti': 100,
    'Casa': 300,
    'Svago': 150,
  };

  Map<String, Map<String, dynamic>> categories = {};
  double score = 100;

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    final tx = await DatabaseHelper.instance.getTransactions();
    final dbBudgets = await DatabaseHelper.instance.getBudgets();
    final dbCats = await DatabaseHelper.instance.getCategories();

    final defaultCats = {
      'Food': {
        'icon': Icons.restaurant.codePoint,
        'color': Colors.deepPurple.value,
      },
      'Trasporti': {
        'icon': Icons.directions_car.codePoint,
        'color': Colors.blue.value,
      },
      'Casa': {
        'icon': Icons.home.codePoint,
        'color': Colors.green.value,
      },
      'Svago': {
        'icon': Icons.sports_esports.codePoint,
        'color': Colors.orange.value,
      },
    };

    setState(() {
      transactions =
          tx.map((e) => FinanceTransaction.fromMap(e)).toList();
      categories = {...defaultCats, ...dbCats};
      dbBudgets.forEach((k, v) => budgets[k] = v);
      score = calculateScore();
    });
  }

  Map<String, double> totals() {
    final map = <String, double>{};
    for (var t in transactions) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  double calculateScore() {
    final t = totals();
    double s = 100;

    t.forEach((cat, spent) {
      final limit = budgets[cat];
      if (limit != null) {
        if (spent > limit) s -= 15;
        else s += 2;
      }
    });

    return s.clamp(0, 100);
  }

  double getBalance() =>
      transactions.fold(0, (sum, t) => sum + t.amount);

  double getMonthlySpending() {
    final now = DateTime.now();
    return transactions
        .where((t) =>
            t.date.month == now.month &&
            t.date.year == now.year)
        .fold(0, (sum, t) => sum + t.amount);
  }

  String getInsight() {
    final t = totals();
    if (t.isEmpty) return "Inizia 🚀";

    final max =
        t.entries.reduce((a, b) => a.value > b.value ? a : b);

    return max.value > 300
        ? "⚠️ Spendi molto in ${max.key}"
        : "💪 Ottimo controllo";
  }

  IconData getIcon(String cat) {
    final data = categories[cat];
    return data == null
        ? Icons.category
        : IconData(data['icon'], fontFamily: 'MaterialIcons');
  }

  Color getColor(String cat) {
    final data = categories[cat];
    return data == null
        ? Colors.deepPurple
        : Color(data['color']);
  }

  List<FlSpot> chart() {
    double total = 0;
    return List.generate(transactions.length, (i) {
      total += transactions[i].amount;
      return FlSpot(i.toDouble(), total);
    });
  }

  Future<void> editBudget(String cat) async {
    final controller =
        TextEditingController(text: budgets[cat].toString());

    final val = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("Budget $cat",
            style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annulla")),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, double.tryParse(controller.text)),
              child: const Text("Salva")),
        ],
      ),
    );

    if (val != null) {
      await DatabaseHelper.instance.insertOrUpdateBudget(cat, val);
      loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = totals();

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: () async {
          final r = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddTransactionScreen(),
            ),
          );
          if (r == true) loadAll();
        },
        child: const Icon(Icons.add),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [

              const Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Finance Tracker",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // DASHBOARD
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Saldo totale",
                        style: TextStyle(color: Colors.white54)),
                    Text(
                      "€${getBalance().toStringAsFixed(0)}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Spesa mese: €${getMonthlySpending().toStringAsFixed(0)}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),

                    LiquidGlass(
                      child: Text(
                        getInsight(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // GRAFICO
              Padding(
                padding: const EdgeInsets.all(16),
                child: LiquidGlass(
                  child: SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: transactions.isEmpty
                                ? [FlSpot(0, 0), FlSpot(1, 0)]
                                : chart(),
                            isCurved: true,
                            color: Colors.white,
                            barWidth: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // BUDGET CARD
              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: categories.keys.map((cat) {
                    final spent = t[cat] ?? 0;
                    final limit = budgets[cat] ?? 0;

                    return Pressable(
                      onTap: () => editBudget(cat),
                      child: Container(
                        width: 160,
                        margin: const EdgeInsets.all(10),
                        child: LiquidGlassCard(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(getIcon(cat),
                                      color: getColor(cat), size: 18),
                                  const SizedBox(width: 6),
                                  Text(cat,
                                      style: const TextStyle(
                                          color: Colors.white)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text("€$spent",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18)),
                              Text("/ €$limit",
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12)),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                minHeight: 4,
                                value: limit == 0
                                    ? 0
                                    : (spent / limit).clamp(0, 1),
                                color: getColor(cat),
                                backgroundColor: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // LISTA
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                itemBuilder: (_, i) {
                  final tx = transactions[i];

                  return Dismissible(
                    key: Key(tx.id.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete,
                          color: Colors.white),
                    ),
                    onDismissed: (_) async {
                      await DatabaseHelper.instance
                          .deleteTransaction(tx.id!);
                      loadAll();
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: getColor(tx.category),
                        child: Icon(getIcon(tx.category),
                            color: Colors.white),
                      ),
                      title: Text(tx.title,
                          style:
                              const TextStyle(color: Colors.white)),
                      subtitle: Text(tx.category,
                          style:
                              const TextStyle(color: Colors.white70)),
                      trailing: Text("€${tx.amount}",
                          style: const TextStyle(
                              color: Colors.greenAccent)),
                    ),
                  );
                },
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
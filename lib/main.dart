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

// 🔥 PRESS EFFECT
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

    final merged = {...defaultCats, ...dbCats};

    setState(() {
      transactions =
          tx.map((e) => FinanceTransaction.fromMap(e)).toList();
      categories = merged;
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
    double total = 0;

    t.forEach((cat, spent) {
      total += spent;
      final limit = budgets[cat];
      if (limit != null) {
        if (spent > limit) {
          s -= 15;
        } else {
          s += 2;
        }
      }
    });

    s -= (total / 2000) * 5;
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
    if (t.isEmpty) return "Inizia a tracciare le spese 🚀";

    final maxCat =
        t.entries.reduce((a, b) => a.value > b.value ? a : b);

    return maxCat.value > 300
        ? "⚠️ Spendi molto in ${maxCat.key}"
        : "💪 Ottimo controllo delle spese";
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

  // ✅ FIX BUDGET EDIT
  Future<void> editBudget(String cat) async {
    HapticFeedback.lightImpact();

    final controller =
        TextEditingController(text: budgets[cat]?.toString() ?? "0");

    final result = await showDialog<double>(
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

    if (result != null) {
      await DatabaseHelper.instance.insertOrUpdateBudget(cat, result);
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
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Finance Tracker",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        getInsight(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // SCORE + CHART
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Colors.deepPurple, Colors.black],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Score",
                            style: TextStyle(color: Colors.white70)),
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: score),
                          duration: const Duration(milliseconds: 800),
                          builder: (_, value, __) => Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(
                                fontSize: 40,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          minY: 0,
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
                  ],
                ),
              ),

              // BUDGET + GLOW + TAP
              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: categories.keys.map((cat) {
                    final spent = t[cat] ?? 0;
                    final limit = budgets[cat] ?? 0;

                    return Pressable(
                      onTap: () => editBudget(cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 160,
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: getColor(cat).withOpacity(0.15),
                              blurRadius: 25,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(getIcon(cat),
                                    color: getColor(cat)),
                                const SizedBox(width: 6),
                                Text(cat,
                                    style: const TextStyle(
                                        color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text("€$spent",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18)),
                            Text("/ €$limit",
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12)),
                            const SizedBox(height: 6),
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
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(16),
                      ),
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
                          style: const TextStyle(
                              color: Colors.white70)),
                      trailing: Text(
                        "€${tx.amount}",
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold),
                      ),
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
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

  Set<String> alerts = {};
  double score = 100;

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    final tx = await DatabaseHelper.instance.getTransactions();
    final dbBudgets = await DatabaseHelper.instance.getBudgets();

    setState(() {
      transactions = tx
          .map((e) => FinanceTransaction.fromMap(e))
          .toList();

      dbBudgets.forEach((k, v) => budgets[k] = v);

      score = calculateScore();
    });

    checkBudgets();
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

  Future<void> notify(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'budget',
      'Budget Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await notificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  void checkBudgets() {
    final t = totals();

    t.forEach((cat, spent) {
      final limit = budgets[cat];

      if (limit != null) {
        final p = spent / limit;

        if (p > 1 && !alerts.contains(cat)) {
          alerts.add(cat);
          notify("⚠️ Budget", "Sforato $cat");
        }
      }
    });
  }

  List<FlSpot> chart() {
    double total = 0;
    return List.generate(transactions.length, (i) {
      total += transactions[i].amount;
      return FlSpot(i.toDouble(), total);
    });
  }

  IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Trasporti':
        return Icons.directions_car;
      case 'Casa':
        return Icons.home;
      case 'Svago':
        return Icons.sports_esports;
      default:
        return Icons.category;
    }
  }

  Future<void> editBudget(String cat) async {
    HapticFeedback.lightImpact();

    final c = TextEditingController(text: budgets[cat].toString());

    final val = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Budget $cat"),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annulla")),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, double.tryParse(c.text)),
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
        elevation: 0,
        backgroundColor: Colors.transparent,
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

      body: SingleChildScrollView(
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // SCORE + GRAFICO
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
                            fontWeight: FontWeight.bold,
                          ),
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
                            dotData: FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // BUDGET
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: budgets.keys.map((cat) {
                  final spent = t[cat] ?? 0;
                  final limit = budgets[cat]!;

                  return GestureDetector(
                    onTap: () => editBudget(cat),
                    child: Container(
                      width: 160,
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(cat,
                              style: const TextStyle(
                                  color: Colors.white)),
                          const SizedBox(height: 8),
                          Text("€$spent",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18)),
                          Text("/ €$limit",
                              style: const TextStyle(
                                  color: Colors.white54)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // LISTA SPESE
            transactions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      "Aggiungi la tua prima spesa 🚀",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    itemBuilder: (_, i) {
                      final tx = transactions[i];

                      return Dismissible(
                        key: Key(tx.id.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete,
                              color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          await DatabaseHelper.instance
                              .deleteTransaction(tx.id!);
                          loadAll();
                        },
                        child: ListTile(
                          title: Text(tx.title,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(tx.category,
                              style: const TextStyle(
                                  color: Colors.white70)),
                          trailing: Text(
                            "€${tx.amount}",
                            style: const TextStyle(
                                color: Colors.greenAccent),
                          ),
                        ),
                      );
                    },
                  ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
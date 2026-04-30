import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';

class ChartScreen extends StatelessWidget {
  final List<FinanceTransaction> transactions;

  const ChartScreen({super.key, required this.transactions});

  Map<String, double> getCategoryTotals() {
    final Map<String, double> data = {};

    for (var t in transactions) {
      data[t.category] = (data[t.category] ?? 0) + t.amount;
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    final data = getCategoryTotals();

    return Scaffold(
      appBar: AppBar(title: const Text('Grafico Spese')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: PieChart(
          PieChartData(
            sections: data.entries.map((entry) {
              return PieChartSectionData(
                value: entry.value,
                title: '${entry.key}\n€${entry.value.toStringAsFixed(0)}',
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
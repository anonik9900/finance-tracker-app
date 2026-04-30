import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../database/database_helper.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState
    extends State<AddTransactionScreen> {
  final titleController = TextEditingController();
  final amountController = TextEditingController();

  String selectedCategory = 'Food';

  Map<String, Map<String, dynamic>> categories = {};

  final iconOptions = [
    Icons.restaurant,
    Icons.directions_car,
    Icons.home,
    Icons.sports_esports,
    Icons.shopping_bag,
    Icons.fitness_center,
    Icons.school,
    Icons.medical_services,
  ];

  final colorOptions = [
    Colors.deepPurple,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    final dbCats = await DatabaseHelper.instance.getCategories();

    final defaultCats = {
      'Food': {
        'icon': Icons.restaurant,
        'color': Colors.deepPurple
      },
      'Trasporti': {
        'icon': Icons.directions_car,
        'color': Colors.blue
      },
      'Casa': {'icon': Icons.home, 'color': Colors.green},
      'Svago': {
        'icon': Icons.sports_esports,
        'color': Colors.orange
      },
    };

    final merged = {
      ...defaultCats,
      ...dbCats.map(
        (k, v) => MapEntry(
          k,
          {
            'icon':
                IconData(v['icon']!, fontFamily: 'MaterialIcons'),
            'color': Color(v['color']!)
          },
        ),
      ),
    };

    setState(() {
      categories = merged;
      selectedCategory = categories.keys.first;
    });
  }

  Future<void> save() async {
    final title = titleController.text;
    final amount =
        double.tryParse(amountController.text) ?? 0;

    if (title.isEmpty || amount <= 0) return;

    final tx = FinanceTransaction(
      title: title,
      amount: amount,
      category: selectedCategory,
      type: 'expense',
      date: DateTime.now(),
    );

    await DatabaseHelper.instance.insertTransaction(tx.toMap());

    Navigator.pop(context, true);
  }

  // 🔥 AGGIUNGI CATEGORIA COMPLETO
  Future<void> addCategory() async {
    final controller = TextEditingController();
    IconData selectedIcon = iconOptions.first;
    Color selectedColor = colorOptions.first;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("Nuova Categoria",
                  style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Nome categoria",
                        hintStyle:
                            TextStyle(color: Colors.white38),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ICON PICKER
                    Wrap(
                      spacing: 10,
                      children: iconOptions.map((icon) {
                        final selected = icon == selectedIcon;
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              selectedIcon = icon;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.deepPurple
                                  : Colors.grey[800],
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child:
                                Icon(icon, color: Colors.white),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // COLOR PICKER
                    Wrap(
                      spacing: 10,
                      children: colorOptions.map((c) {
                        final selected = c == selectedColor;
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              selectedColor = c;
                            });
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: selected
                                  ? Border.all(
                                      color: Colors.white,
                                      width: 2)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Annulla")),
                TextButton(
                  onPressed: () async {
                    if (controller.text.isEmpty) return;

                    await DatabaseHelper.instance.insertCategory(
                      controller.text,
                      selectedIcon.codePoint,
                      selectedColor.value,
                    );

                    Navigator.pop(context);
                    loadCategories();
                  },
                  child: const Text("Salva"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,

      appBar: AppBar(
        title: const Text(
          "Nuova Spesa",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Text(
                "Dettagli",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Descrizione (es. Pizza 🍕)",
                  hintStyle:
                      const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Importo (€)",
                  hintStyle:
                      const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Categoria",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [

                  // 🔹 CATEGORIE
                  ...categories.keys.map((cat) {
                    final isSelected = cat == selectedCategory;
                    final data = categories[cat]!;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedCategory = cat;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: data['color'],
                          borderRadius:
                              BorderRadius.circular(20),
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white,
                                  width: 2)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              data['icon'],
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat,
                              style: const TextStyle(
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // 🔥 BOTTONE +
                  GestureDetector(
                    onTap: addCategory,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.add,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: save,
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF7F5AF0),
                          Color(0xFF5A31F4),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        "Aggiungi Spesa",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
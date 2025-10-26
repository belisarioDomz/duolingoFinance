import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 🐠 --- IA Assistant (Finny) ---
class IAAssistant extends StatefulWidget {
  final String username;

  const IAAssistant({super.key, required this.username});

  @override
  State<IAAssistant> createState() => _IAAssistantState();
}

class _IAAssistantState extends State<IAAssistant> {
  String? _message;
  bool _isLoading = false;

  Future<void> _getAdvice() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/ai/ask_mascot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.username,
          'question': 'Give me a personalized financial advice'
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _message = data['answer'] ?? 'No advice received';
        });
      } else {
        setState(() {
          _message = '🐠 Error fetching advice from IA';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Server connection error 😕';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAdviceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💬 Finny IA'),
        content: _isLoading
            ? const SizedBox(
                height: 50,
                child: Center(child: CircularProgressIndicator()),
              )
            : Text(_message ?? 'Tap Finny to get advice'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await _getAdvice();
        _showAdviceDialog();
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.shade100,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
          image: const DecorationImage(
            image: AssetImage('assets/mascotaLogIn.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

// 🧭 --- Goals Screen ---
class GoalsScreen extends StatefulWidget {
  final int idUser;
  final String username;

  const GoalsScreen({super.key, required this.idUser, required this.username});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List ahorroGoals = [];
  List inversionGoals = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchGoals();
  }

  Future<void> fetchGoals() async {
    setState(() {
      isLoading = true;
    });
    try {
      final ahorroResponse = await http.get(
        Uri.parse('http://10.0.2.2:5000/goals/ahorro/${widget.idUser}'),
      );
      final inversionResponse = await http.get(
        Uri.parse('http://10.0.2.2:5000/goals/inversion/${widget.idUser}'),
      );

      setState(() {
        ahorroGoals = json.decode(ahorroResponse.body);
        inversionGoals = json.decode(inversionResponse.body);
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching goals: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> addGoal(String type) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    String backendType = type == 'Saving' ? 'ahorro' : 'inversion';

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('New $type Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Goal Name'),
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Goal Amount'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  amountController.text.isNotEmpty) {
                final response = await http.post(
                  Uri.parse('http://10.0.2.2:5000/goals/$backendType'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    "id_user": widget.idUser,
                    "nombre_meta": nameController.text,
                    "monto_objetivo": double.parse(amountController.text),
                  }),
                );

                if (response.statusCode == 201) {
                  Navigator.pop(context);
                  fetchGoals();
                } else {
                  print("Error creating goal: ${response.body}");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error creating goal')),
                  );
                }
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  Future<void> updateGoal(String type, Map goal) async {
    final currentController =
        TextEditingController(text: (goal['monto_actual'] ?? 0).toString());
    final targetController =
        TextEditingController(text: goal['monto_objetivo'].toString());

    String backendType = type == 'Saving' ? 'ahorro' : 'inversion';

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Update $type Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              decoration: const InputDecoration(labelText: 'Current Amount'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: targetController,
              decoration: const InputDecoration(labelText: 'Target Amount'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              double? current = double.tryParse(currentController.text);
              double? target = double.tryParse(targetController.text);

              if (current != null || target != null) {
                final idMeta = backendType == 'ahorro'
                    ? goal['id_ahorro']
                    : goal['id_inversion'];

                final response = await http.put(
                  Uri.parse(
                      'http://10.0.2.2:5000/goals/$backendType/$idMeta'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    if (current != null) "monto_actual": current,
                    if (target != null) "monto_objetivo": target,
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  fetchGoals();
                } else {
                  print("Error updating goal: ${response.body}");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error updating goal')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget goalCard(Map goal) {
    double progress = 0;
    if (goal['monto_objetivo'] > 0) {
      progress = (goal['monto_actual'] ?? 0) / goal['monto_objetivo'];
      if (progress > 1) progress = 1;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(goal['nombre_meta']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              color: Colors.green,
            ),
            const SizedBox(height: 4),
            Text(
                'Progress: \$${goal['monto_actual'] ?? 0} / \$${goal['monto_objetivo']}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                String type = ahorroGoals.contains(goal) ? 'Saving' : 'Investment';
                updateGoal(type, goal);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                String backendType =
                    ahorroGoals.contains(goal) ? 'ahorro' : 'inversion';
                final idMeta = backendType == 'ahorro'
                    ? goal['id_ahorro']
                    : goal['id_inversion'];
                final url = 'http://10.0.2.2:5000/goals/$backendType/$idMeta';
                final res = await http.delete(Uri.parse(url));

                if (res.statusCode == 200) {
                  fetchGoals();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error deleting goal')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Goals'),
        backgroundColor: Colors.blue.shade900,
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchGoals,
          ),
        ],
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100), // space for Finny
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Savings 💰',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      ...ahorroGoals.map((g) => goalCard(g)).toList(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Saving Goal'),
                          onPressed: () => addGoal('Saving'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Investments 📈',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      ...inversionGoals.map((g) => goalCard(g)).toList(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Investment Goal'),
                          onPressed: () => addGoal('Investment'),
                        ),
                      ),
                    ],
                  ),
                ),

          // 🐠 Finny IA fixed at bottom left
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: IAAssistant(username: widget.username),
            ),
          ),
        ],
      ),
    );
  }
}

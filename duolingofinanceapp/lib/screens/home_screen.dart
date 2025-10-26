import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final int idUser;
  const HomeScreen({super.key, required this.username, required this.idUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List movimientos = [];
  bool _loading = true;

  double totalIngresos = 0;
  double totalEgresos = 0;

  @override
  void initState() {
    super.initState();
    fetchMovements();
  }

  Future<void> fetchMovements() async {
    setState(() => _loading = true);
    final response = await http.get(Uri.parse(
        'http://10.0.2.2:5000/movements/${widget.idUser}')); // 10.0.2.2 para emulador
    if (response.statusCode == 200) {
      setState(() {
        movimientos = jsonDecode(response.body);
        _calculateBalance();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar movimientos')));
    }
  }

  void _calculateBalance() {
    totalIngresos = 0;
    totalEgresos = 0;
    for (var mov in movimientos) {
      if (mov['tipo'] == 'Ingreso') {
        totalIngresos += mov['monto'];
      } else {
        totalEgresos += mov['monto'];
      }
    }
  }

  void _showAddMovementDialog() {
    String tipo = 'Egreso';
    String? categoria;

    final descripcionController = TextEditingController();
    final montoController = TextEditingController();

    // Categorías según tipo
    final List<String> categoriasEgreso = [
      'Comida',
      'Transporte',
      'Entretenimiento',
      'Salud',
      'Educacion',
      'Ahorro',
      'Renta',
      'Otros'
    ];
    final List<String> categoriasIngreso = [
      'Sueldo',
      'Otros ingresos'
    ];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Agregar Movimiento'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                // Tipo
                DropdownButtonFormField<String>(
                  value: tipo,
                  items: const [
                    DropdownMenuItem(value: 'Ingreso', child: Text('Ingreso')),
                    DropdownMenuItem(value: 'Egreso', child: Text('Egreso')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setStateDialog(() {
                        tipo = value;
                        categoria = null; // reset categoría al cambiar tipo
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                const SizedBox(height: 8),
                // Categoría
                DropdownButtonFormField<String>(
                  value: categoria,
                  items: (tipo == 'Ingreso' ? categoriasIngreso : categoriasEgreso)
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (value) => setStateDialog(() => categoria = value),
                  decoration: const InputDecoration(labelText: 'Categoría'),
                ),
                const SizedBox(height: 8),
                // Descripción
                TextField(
                  controller: descripcionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 8),
                // Monto
                TextField(
                  controller: montoController,
                  decoration: const InputDecoration(labelText: 'Monto'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (categoria == null || montoController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Completa todos los campos')));
                  return;
                }

                final descripcion = descripcionController.text;
                final monto = double.tryParse(montoController.text) ?? 0;

                final res = await http.post(
                  Uri.parse('http://10.0.2.2:5000/movements'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'id_user': widget.idUser,
                    'categoria': categoria,
                    'nota': descripcion,
                    'monto': monto,
                    'tipo': tipo
                  }),
                );

                if (res.statusCode == 201) {
                  Navigator.pop(context);
                  fetchMovements();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error al agregar movimiento')));
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  String formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    double balance = totalIngresos - totalEgresos;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${widget.username}', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Balance general
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade900,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Ingresos', style: TextStyle(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('\$${totalIngresos.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Egresos', style: TextStyle(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('\$${totalEgresos.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Balance', style: TextStyle(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('\$${balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: balance >= 0 ? Colors.greenAccent : Colors.redAccent,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Lista de movimientos
                Expanded(
                  child: movimientos.isEmpty
                      ? const Center(
                          child: Text(
                            'No tienes movimientos aún',
                            style: TextStyle(color: Colors.black),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: movimientos.length,
                          itemBuilder: (_, index) {
                            final mov = movimientos[index];
                            final color = mov['tipo'] == 'Ingreso' ? Colors.green.shade100 : Colors.red.shade100;
                            final icon = mov['tipo'] == 'Ingreso' ? Icons.arrow_downward : Icons.arrow_upward;

                            return Card(
                              color: color,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: Icon(icon, color: Colors.blue.shade900),
                                title: Text('${mov['nota']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    'Categoría: ${mov['categoria']}\nFecha: ${formatDate(mov['fecha'])}',
                                    style: const TextStyle(color: Colors.black87)),
                                trailing: Text('\$${mov['monto']}',
                                    style: TextStyle(
                                        color: mov['tipo'] == 'Ingreso' ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold)),
                                onTap: () {
                                  // Podríamos abrir modal de edición
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMovementDialog,
        child: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blue.shade900,
      ),
    );
  }
}

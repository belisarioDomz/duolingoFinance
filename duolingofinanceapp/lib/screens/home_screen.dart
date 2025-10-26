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

  // Filtro de fechas
  DateTime? fechaInicio;
  DateTime? fechaFin;

  @override
  void initState() {
    super.initState();
    fetchMovements();
  }

  Future<void> fetchMovements() async {
    setState(() => _loading = true);
    final response = await http.get(Uri.parse(
        'http://10.0.2.2:5000/movements/${widget.idUser}'));
    if (response.statusCode == 200) {
      setState(() {
        movimientos = jsonDecode(response.body);
        _applyDateFilter();
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

  void _applyDateFilter() {
    if (fechaInicio != null && fechaFin != null) {
      movimientos = movimientos.where((mov) {
        final fecha = DateTime.parse(mov['fecha']);
        return fecha.isAfter(fechaInicio!.subtract(const Duration(days:1))) &&
               fecha.isBefore(fechaFin!.add(const Duration(days:1)));
      }).toList();
    }
  }

  Color categoryColor(String categoria) {
    switch (categoria) {
      case 'Comida':
        return Colors.orange.shade100;
      case 'Transporte':
        return Colors.blue.shade100;
      case 'Entretenimiento':
        return Colors.purple.shade100;
      case 'Salud':
        return Colors.red.shade100;
      case 'Educacion':
        return Colors.teal.shade100;
      case 'Ahorro':
        return Colors.green.shade100;
      case 'Renta':
        return Colors.pink.shade100; // pastel más agradable
      case 'Sueldo':
        return Colors.green.shade200;
      case 'Otros Ingresos':
        return Colors.blue.shade200;
      default:
        return Colors.grey.shade200;
    }
  }

  void _showAddMovementDialog() {
    String tipo = 'Egreso';
    String categoria = 'Comida';
    final descripcionController = TextEditingController();
    final montoController = TextEditingController();

    List<String> egresoCategorias = [
      'Comida',
      'Transporte',
      'Entretenimiento',
      'Salud',
      'Educacion',
      'Ahorro',
      'Renta',
      'Otros'
    ];
    List<String> ingresoCategorias = [
      'Sueldo',
      'Otros Ingresos'
    ];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Agregar Movimiento'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: tipo,
                  items: const [
                    DropdownMenuItem(value: 'Ingreso', child: Text('Ingreso')),
                    DropdownMenuItem(value: 'Egreso', child: Text('Egreso')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        tipo = value;
                        categoria = tipo == 'Ingreso' ? ingresoCategorias[0] : egresoCategorias[0];
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: categoria,
                  items: (tipo == 'Ingreso' ? ingresoCategorias : egresoCategorias)
                      .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => categoria = value);
                  },
                  decoration: const InputDecoration(labelText: 'Categoría'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descripcionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 10),
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

  void _deleteMovement(int idMov) async {
    final res = await http.delete(
        Uri.parse('http://10.0.2.2:5000/movements/$idMov'));
    if (res.statusCode == 200) {
      fetchMovements();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al borrar movimiento')));
    }
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
        title: Text('Hola, ${widget.username}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () async {
              final pickedStart = await showDatePicker(
                  context: context,
                  initialDate: fechaInicio ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now());
              final pickedEnd = await showDatePicker(
                  context: context,
                  initialDate: fechaFin ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now());
              if (pickedStart != null && pickedEnd != null) {
                setState(() {
                  fechaInicio = pickedStart;
                  fechaFin = pickedEnd;
                  _applyDateFilter();
                  _calculateBalance();
                });
              }
            },
          )
        ],
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: Column(
          children: [
            // Contenedor blanco para balance y lista
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    // Balance general
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Ingresos', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('\$${totalIngresos.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Egresos', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('\$${totalEgresos.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Balance', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('\$${balance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      color: balance >= 0 ? Colors.green : Colors.red,
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
                              itemCount: movimientos.length,
                              itemBuilder: (_, index) {
                                final mov = movimientos[index];
                                final color = categoryColor(mov['categoria']);
                                final icon = mov['tipo'] == 'Ingreso'
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward;

                                return Card(
                                  color: color,
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  child: ListTile(
                                    leading: Icon(icon, color: Colors.blue.shade900),
                                    title: Text('${mov['nota']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                        'Categoría: ${mov['categoria']}\nFecha: ${formatDate(mov['fecha'])}',
                                        style: const TextStyle(color: Colors.black87)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteMovement(mov['id_movimiento']),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMovementDialog,
        child: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blue.shade900,
      ),
    );
  }
}
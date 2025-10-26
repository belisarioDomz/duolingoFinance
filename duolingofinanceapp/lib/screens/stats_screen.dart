import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StatsScreen extends StatefulWidget {
  final int idUser;
  const StatsScreen({super.key, required this.idUser});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List movimientos = [];
  bool _loading = true;

  int rachaMeses = 0;
  String mesMayorIngreso = '';
  Map<String, double> balancesPorMes = {}; // mes: ingreso-egreso

  @override
  void initState() {
    super.initState();
    fetchMovements();
  }

  Future<void> fetchMovements() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(Uri.parse(
          'http://10.0.2.2:5000/movements/${widget.idUser}'));
      if (response.statusCode == 200) {
        movimientos = jsonDecode(response.body);
        _calcularEstadisticas();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cargar movimientos')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _calcularEstadisticas() {
    balancesPorMes = {};
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      balancesPorMes[DateFormat('MMM yyyy').format(month)] = 0;
    }

    for (var mov in movimientos) {
      final fecha = DateTime.parse(mov['fecha']);
      final monthKey =
          DateFormat('MMM yyyy').format(DateTime(fecha.year, fecha.month, 1));
      if (balancesPorMes.containsKey(monthKey)) {
        final value = balancesPorMes[monthKey]!;
        balancesPorMes[monthKey] =
            mov['tipo'] == 'Ingreso' ? value + mov['monto'] : value - mov['monto'];
      }
    }

    // Mes con mayor ingreso
    double maxBalance = double.negativeInfinity;
    mesMayorIngreso = '';
    balancesPorMes.forEach((mes, balance) {
      if (balance > maxBalance) {
        maxBalance = balance;
        mesMayorIngreso = mes;
      }
    });

    // Racha de meses positivos
    rachaMeses = 0;
    final sortedMeses = balancesPorMes.keys.toList()
      ..sort((a, b) =>
          DateFormat('MMM yyyy').parse(a).compareTo(DateFormat('MMM yyyy').parse(b)));

    for (var mes in sortedMeses) {
      if (balancesPorMes[mes]! > 0) {
        rachaMeses += 1;
      } else {
        rachaMeses = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = balancesPorMes.keys.toList();
    final balances = balancesPorMes.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tus Estadísticas'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Racha de meses ---
                  _buildStatCard(
                    color: Colors.green.shade400,
                    title: 'Racha de meses positivos',
                    value: '$rachaMeses 💪',
                  ),
                  const SizedBox(height: 16),

                  // --- Mes con mayor ingreso ---
                  _buildStatCard(
                    color: Colors.amber.shade600,
                    title: 'Mes con mayor ingreso',
                    value: mesMayorIngreso,
                  ),
                  const SizedBox(height: 24),

                  // --- Gráfico de barras mensual ---
                  const Text('Balance mensual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (balances.map((e) => e.abs()).reduce((a, b) => a > b ? a : b)) + 200,
                        barGroups: List.generate(balances.length, (i) {
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: balances[i].abs(),
                                color: balances[i] >= 0 ? Colors.green : Colors.red,
                                width: 20,
                                borderRadius: BorderRadius.circular(4),
                              )
                            ],
                          );
                        }),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  int index = value.toInt();
                                  if (index < 0 || index >= months.length) return const SizedBox();
                                  return Transform.rotate(
                                    angle: 0.8, // radians, aprox 45°
                                    child: Text(
                                      months[index],
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: 1000,
                              getTitlesWidget: (value, _) {
                                return Text('\$${value.toInt()}',
                                    style: const TextStyle(fontSize: 10));
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Botón de estadísticas extra ---
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('Ver más estadísticas'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => SizedBox(
                            height: 250,
                            child: ListView(
                              children: const [
                                ListTile(title: Text('Promedio ingresos')),
                                ListTile(title: Text('Promedio egresos')),
                                ListTile(title: Text('Mes con mayor gasto')),
                                ListTile(title: Text('Racha de ahorro')),
                                ListTile(title: Text('Progreso de metas')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({required Color color, required String title, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

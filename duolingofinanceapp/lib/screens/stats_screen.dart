import 'package:flutter/material.dart';

class StatsScreen extends StatelessWidget {
  final String username;
  final int idUser;
  const StatsScreen({super.key, required this.username, required this.idUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: const Center(
        child: Text(
          'Aquí irán los dashboards de ingresos y egresos',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

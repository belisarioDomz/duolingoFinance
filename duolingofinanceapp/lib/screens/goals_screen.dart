import 'package:flutter/material.dart';

class GoalsScreen extends StatelessWidget {
  final String username;
  final int idUser;
  const GoalsScreen({super.key, required this.username, required this.idUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metas'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: const Center(
        child: Text(
          'Aquí se mostrarán tus metas y objetivos de ahorro',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

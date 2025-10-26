import 'package:flutter/material.dart';

class GoalsScreen extends StatelessWidget {
  final int idUser;
  const GoalsScreen({super.key, required this.idUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: Center(
        child: Text('Goals for user $idUser'),
      ),
    );
  }
}


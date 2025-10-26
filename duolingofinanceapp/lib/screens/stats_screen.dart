import 'package:flutter/material.dart';

class StatsScreen extends StatelessWidget {
  final int idUser;
  const StatsScreen({super.key, required this.idUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: Center(
        child: Text('Stats for user $idUser'),
      ),
    );
  }
}

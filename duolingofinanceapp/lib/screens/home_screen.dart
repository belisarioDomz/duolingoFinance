import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final String username;

  HomeScreen({required this.username}); // recibimos el usuario para personalizar la bienvenida

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Duolingo Financiero'),
        automaticallyImplyLeading: false, // elimina el botón "atrás"
      ),
      body: Center(
        child: Text(
          '¡Bienvenido, $username!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

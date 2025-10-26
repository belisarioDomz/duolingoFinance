import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class IAAssistant extends StatefulWidget {
  final String username;

  const IAAssistant({super.key, required this.username});

  @override
  State<IAAssistant> createState() => _IAAssistantState();
}

class _IAAssistantState extends State<IAAssistant> {
  String? _mensaje;
  bool _isLoading = false;

  Future<void> _getAdvice() async {
    setState(() {
      _isLoading = true;
      _mensaje = null;
    });

    try {
      final response = await http.post(
        // ⚠️ Usa tu IP local si pruebas desde emulador o dispositivo físico
        Uri.parse('http://localhost:5000/ai/ask_mascot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.username,
          'question': 'Dame un consejo financiero personalizado'
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _mensaje = data['answer'];
        });
      } else {
        setState(() {
          _mensaje = '🐠 Error al obtener la respuesta de la IA';
        });
      }
    } catch (e) {
      setState(() {
        _mensaje = 'Error de conexión con el servidor 😕';
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
            : Text(_mensaje ?? 'Presiona a Finny para recibir un consejo'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
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

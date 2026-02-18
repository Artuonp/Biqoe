import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class GuestScreen extends StatefulWidget {
  const GuestScreen({super.key});

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  @override
  void initState() {
    super.initState();
    _signInAnonymously();
  }

  Future<void> _signInAnonymously() async {
    try {
      // 1. Iniciamos sesión anónima en Firebase
      // Esto genera un UID temporal para que las reglas de seguridad
      // de Firestore permitan leer los destinos.
      await FirebaseAuth.instance.signInAnonymously();

      if (mounted) {
        // 2. Redirigir al Home real
        // El usuario ya es "válido" para el sistema, así que entra normal.
        context.go('/');
      }
    } catch (e) {
      debugPrint("Error al entrar como invitado: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al entrar como invitado. Intenta de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
        // Si falla, lo devolvemos al login para que no se quede atrapado
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mientras se autentica, mostramos un spinner elegante
    return const Scaffold(
      backgroundColor: Color.fromARGB(255, 243, 247, 254),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color.fromRGBO(17, 48, 73, 1),
            ),
            SizedBox(height: 20),
            Text(
              'Entrando como invitado...',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Color.fromRGBO(17, 48, 73, 1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

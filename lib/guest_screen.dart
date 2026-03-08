import 'package:flutter/foundation.dart';
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
      if (kIsWeb) {
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.NONE);
        } catch (_) {}
      }
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint(
          "Safari bloqueó la sesión anónima. Entrando en Modo Lectura: $e");
      // Ya no mostramos el SnackBar rojo ni lo mandamos al login.
    } finally {
      // ESTA ES LA MAGIA: FALLE O NO FALLÉ, LO MANDAMOS AL HOME
      if (mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              'Preparando tu experiencia...',
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

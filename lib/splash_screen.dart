// Importaciones necesarias para el funcionamiento de la pantalla de splash
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_screen.dart'; // Importa la pantalla de inicio de sesión
import 'search_screen.dart'; // Importa la pantalla de búsqueda

// Clase principal de la pantalla de splash
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

// Estado de la pantalla de splash
class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Establece un temporizador para redirigir a la pantalla adecuada después de 3 segundos
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _checkAuthentication();
      }
    });
  }

  // Verifica el estado de autenticación del usuario
  void _checkAuthentication() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Usuario autenticado, redirigir a la pantalla de búsqueda
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SearchScreen(
            userId: user.uid,
            destinations: const [],
          ),
        ),
      );
    } else {
      // Usuario no autenticado, redirigir a la pantalla de inicio de sesión
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(), // Empuja el logo hacia el centro verticalmente
            Center(
              child: Image.asset(
                'assets/images/Biqoe logo1.png', // Ruta de la imagen del logo
                width: 170.0,
                height: 170.0,
              ),
            ),
            const Spacer(), // Empuja el texto hacia abajo
            const Text(
              'By Biqono',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 118, 117, 117),
              ),
            ),
            const SizedBox(height: 20), // Añade un espacio debajo del texto
          ],
        ),
      ),
    );
  }
}

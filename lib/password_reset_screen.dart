import 'package:flutter/material.dart';
import 'login_screen.dart'; // Asegúrate de importar la pantalla de inicio de sesión

class PasswordResetScreen extends StatelessWidget {
  final String email;

  const PasswordResetScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Cambia el color de fondo a blanco
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Centrar los elementos verticalmente
            crossAxisAlignment: CrossAxisAlignment.center, // Centrar los elementos horizontalmente
            children: [
              const Text(
                'Se ha enviado un mensaje a tu correo con un link para cambiar tu contraseña',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18.0),
              ),
              const SizedBox(height: 24.0), // Espacio entre el mensaje y el botón

              // Botón para volver a la pantalla de inicio de sesión
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginFormScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 100.0, vertical: 16.0),
                  backgroundColor: Colors.blue, // Color de fondo del botón
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0), // Bordes redondeados
                  ),
                ),
                child: const Text(
                  'Iniciar sesión',
                  style: TextStyle(color: Colors.white), // Color del texto del botón
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
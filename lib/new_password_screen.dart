import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_screen.dart'; // Asegúrate de importar la pantalla principal

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  NewPasswordScreenState createState() => NewPasswordScreenState();
}

class NewPasswordScreenState extends State<NewPasswordScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Función para actualizar la contraseña
  void _updatePassword() async {
    String newPassword = _newPasswordController.text;
    String confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showErrorMessage("Por favor, rellena ambos campos");
      return;
    }

    if (newPassword != confirmPassword) {
      _showErrorMessage("Las contraseñas no coinciden");
      return;
    }

    try {
      // Obtener el usuario actual y actualizar la contraseña
      User? user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        if (!mounted) return; // Verificación si el widget está montado
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()), // Cambiado a LoginScreen
        );
      }
    } catch (e) {
      _showErrorMessage("Error al actualizar la contraseña");
    }
  }

  // Función para mostrar el mensaje de error desde la parte superior
  void _showErrorMessage(String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50.0,
        left: MediaQuery.of(context).size.width * 0.1,
        right: MediaQuery.of(context).size.width * 0.1,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(0.0),
            ),
            child: Center(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nueva contraseña"),
        backgroundColor: Colors.white,
        elevation: 0.0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20.0),

            // Campo para la nueva contraseña
            const Text(
              "Nueva contraseña",
              style: TextStyle(fontSize: 18.0),
            ),
            const SizedBox(height: 20.0),

            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Introduce tu nueva contraseña',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20.0),

            // Campo para confirmar la nueva contraseña
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Confirma tu nueva contraseña',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30.0),

            // Botón para crear la nueva contraseña
            Center(
              child: ElevatedButton(
                onPressed: _updatePassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 100.0, vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  backgroundColor: const Color(0xFF4A90E2),
                ),
                child: const Text(
                  'Crear nueva contraseña',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
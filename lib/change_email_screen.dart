import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangeEmailScreen extends StatefulWidget {
  final String userId;

  const ChangeEmailScreen({super.key, required this.userId});

  @override
  ChangeEmailScreenState createState() => ChangeEmailScreenState();
}

class ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final TextEditingController _emailController = TextEditingController();
  String _currentEmail = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentEmail();
  }

  // Cargar el email actual del usuario desde Firestore
  Future<void> _loadCurrentEmail() async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.userId)
        .get();

    if (docSnapshot.exists) {
      setState(() {
        _currentEmail = docSnapshot.data()?['email'] ?? '';
      });
    }
  }

  // Validar el nuevo email
  bool _validateEmail(String email) {
    final emailPattern =
        RegExp(r'^[a-zA-Z0-9._%+-]+@(gmail\.com|outlook\.com|yahoo\.com)$');
    return emailPattern.hasMatch(email);
  }

  // Actualizar el email del usuario en Firestore
  Future<void> _updateEmail() async {
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty) {
      _showErrorSnackbar('El correo no puede estar vacío.');
      return;
    }
    if (!_validateEmail(newEmail)) {
      _showErrorSnackbar('El correo debe ser de Gmail, Outlook o Yahoo.');
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.verifyBeforeUpdateEmail(newEmail);
        await user.sendEmailVerification();

        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(widget.userId)
            .update({'email': newEmail});

        _showSuccessSnackbar(
            'Correo actualizado. Por favor, verifica tu nuevo correo.');
      }
    } catch (e) {
      _showErrorSnackbar('Error al actualizar el correo: $e');
    }
  }

  // Mostrar un snackbar de error
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Mostrar un snackbar de éxito
  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cambiar Correo', style: GoogleFonts.poppins()),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Correo actual: $_currentEmail',
                  style: GoogleFonts.poppins(fontSize: 16)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Nuevo correo',
                  labelStyle: GoogleFonts.poppins(),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _updateEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(128, 17, 48, 73),
                  ),
                  child: Text(
                    'Aplicar',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool isDeleting = false;
  String? errorMessage;

  Future<void> _deleteAccount() async {
    setState(() {
      isDeleting = true;
      errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          errorMessage = 'No hay usuario autenticado.';
          isDeleting = false;
        });
        return;
      }

      // Eliminar datos del usuario en Firestore
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .delete();

      // Si usó Google Sign-In, cerrar sesión
      await GoogleSignIn().signOut();

      // Eliminar cuenta de Firebase Auth
      await user.delete();

      // Navegar a pantalla de confirmación o login
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: const Color.fromARGB(255, 243, 247, 254),
            title: const Text('Cuenta eliminada',
                style: TextStyle(
                  color: Color.fromRGBO(17, 48, 73, 1),
                  fontFamily: 'Poppins',
                )),
            content: const Text('Tu cuenta ha sido eliminada exitosamente.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color.fromRGBO(17, 48, 73, 1),
                )),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context)
                      .popUntil((route) => route.isFirst); // Volver al inicio
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message ?? 'Cuenta eliminada';
        isDeleting = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Cuenta eliminada';
        isDeleting = false;
      });
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color.fromARGB(255, 243, 247, 254),
        title: const Center(
          child: Text(
            '¿Eliminar cuenta?',
            style: TextStyle(
                color: Color.fromRGBO(17, 48, 73, 1), fontFamily: 'Poppins'),
          ),
        ),
        content: const Text(
            'Esta acción eliminará tu cuenta de forma permanente.                      '
            '¿Deseas continuar?',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Color.fromRGBO(17, 48, 73, 1),
            )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar',
                style: TextStyle(
                  color: Color.fromRGBO(17, 48, 73, 1),
                  fontFamily: 'Poppins',
                )),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromRGBO(17, 48, 73, 1),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAccount();
            },
            child: const Text('Eliminar',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                )),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 243, 247, 254),
        iconTheme: const IconThemeData(color: Color.fromRGBO(17, 48, 73, 1)),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.delete_forever,
                  color: Color.fromRGBO(17, 48, 73, 1), size: 80),
              const SizedBox(height: 24),
              const Text(
                'Eliminar cuenta',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(17, 48, 73, 1),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Esta acción es irreversible. Tu cuenta será eliminada permanentemente.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Color.fromRGBO(17, 48, 73, 1),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontFamily: 'Poppins'),
                    textAlign: TextAlign.center,
                  ),
                ),
              isDeleting
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text(
                        'Eliminar mi cuenta',
                        style: TextStyle(
                            fontFamily: 'Poppins', color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromRGBO(17, 48, 73, 1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      onPressed: _showDeleteDialog,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

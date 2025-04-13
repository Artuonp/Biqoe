import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ChangePasswordScreenState createState() => ChangePasswordScreenState();
}

class ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  // Actualizar la contraseña del usuario en Firebase
  Future<void> _updatePassword() async {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty) {
      _showErrorSnackbar('Por favor, complete todos los campos.');
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Reautenticar al usuario
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: oldPassword,
        );
        await user.reauthenticateWithCredential(credential);

        // Actualizar la contraseña
        await user.updatePassword(newPassword);

        _showSuccessSnackbar('Contraseña actualizada correctamente.');
      }
    } catch (e) {
      _showErrorSnackbar('Contraseña anterior incorrecta');
    }
  }

  // Mostrar un snackbar de error
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Mostrar un snackbar de éxito
  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildOldPasswordInputField() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contraseña anterior:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color.fromRGBO(17, 48, 73, 1),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _oldPasswordController,
            obscureText: true,
            style: GoogleFonts.poppins(fontSize: 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Ingresa tu contraseña anterior',
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPasswordInputField() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nueva contraseña:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color.fromRGBO(17, 48, 73, 1),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            style: GoogleFonts.poppins(fontSize: 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Ingresa tu nueva contraseña',
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _updatePassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Aplicar',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const primaryColor = Color.fromRGBO(17, 48, 73, 1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      body: SingleChildScrollView(
        padding:
            EdgeInsets.symmetric(horizontal: size.width * 0.08, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOldPasswordInputField(),
            SizedBox(height: size.height * 0.04),
            _buildNewPasswordInputField(),
            SizedBox(height: size.height * 0.05),
            _buildUpdateButton(),
          ],
        ),
      ),
    );
  }
}

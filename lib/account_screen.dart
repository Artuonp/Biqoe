import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'change_name_screen.dart';
import 'change_password_screen.dart';
import 'delete_account_screen.dart';

class AccountScreen extends StatelessWidget {
  final String userId;

  const AccountScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // FIX: Usamos un ancho de referencia limitado.
    // Si la pantalla es muy ancha (PC), usamos 600px como base para que los textos no sean gigantes.
    final double refWidth = size.width > 600 ? 600 : size.width;

    const primaryColor = Color.fromRGBO(17, 48, 73, 1);
    const backgroundColor = Color.fromARGB(255, 243, 247, 254);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: backgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: backgroundColor,
      // 1. AGREGADO: Center y Container limitado para que en PC se vea centrado y no estirado
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          // 2. AGREGADO: SingleChildScrollView para evitar el RenderFlex Overflow
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              // Usamos refWidth para el padding horizontal
              padding: EdgeInsets.symmetric(horizontal: refWidth * 0.08),
              child: Column(
                children: [
                  SizedBox(height: size.height * 0.04),
                  Text(
                    'Cuenta',
                    style: GoogleFonts.poppins(
                      // Usamos refWidth para el tamaño de fuente
                      fontSize: refWidth * 0.065,
                      fontWeight: FontWeight.w600,
                      color: const Color.fromRGBO(17, 48, 73, 1),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: size.height * 0.05),

                  _buildOptionCard(
                    context: context,
                    refWidth: refWidth, // Pasamos el ancho de referencia
                    icon: Icons.person_outline,
                    title: 'Cambiar Nombre',
                    subtitle: 'Actualiza tu nombre de usuario',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChangeNameScreen(userId: userId),
                      ),
                    ),
                  ),

                  SizedBox(
                      height: 20), // Usamos tamaños fijos para consistencia

                  _buildOptionCard(
                    context: context,
                    refWidth: refWidth,
                    icon: Icons.lock_outline,
                    title: 'Cambiar Contraseña',
                    subtitle: 'Actualiza tu contraseña de acceso',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  _buildOptionCard(
                    context: context,
                    refWidth: refWidth,
                    icon: Icons.delete_outline, // Corregido: Icono de eliminar
                    title: 'Eliminar cuenta',
                    subtitle: 'Elimina tu cuenta de forma permanente',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeleteAccountScreen(),
                      ),
                    ),
                  ),

                  // Espacio extra al final para scroll
                  SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required double refWidth, // Recibimos refWidth
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    const primaryColor = Color.fromRGBO(17, 48, 73, 1);

    return Material(
      borderRadius: BorderRadius.circular(15),
      color: Colors.white,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: EdgeInsets.all(refWidth * 0.05),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.grey.withValues(alpha: (0.2)), // Sintaxis estándar
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(refWidth * 0.035),
                decoration: const BoxDecoration(
                  color: Color.fromARGB(30, 128, 128, 128),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: refWidth * 0.065,
                  color: primaryColor,
                ),
              ),
              SizedBox(width: refWidth * 0.05),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: refWidth * 0.04,
                        fontWeight: FontWeight.w500,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: refWidth * 0.033,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: refWidth * 0.045,
                color: const Color.fromRGBO(17, 48, 73, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

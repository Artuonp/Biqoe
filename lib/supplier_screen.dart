import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'supplier_verify_screen.dart';
import 'supplier_calendar_screen.dart'; // Importa la nueva pantalla

class SupplierScreen extends StatelessWidget {
  final String userId; // Agregamos el parámetro userId

  const SupplierScreen(
      {super.key, required this.userId}); // Constructor actualizado

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromRGBO(17, 48, 73, 1);
    const accentColor = Color.fromRGBO(240, 169, 52, 1);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
        child: Column(
          children: [
            SizedBox(height: size.height * 0.04),
            _buildWelcomeCard(primaryColor),
            SizedBox(height: size.height * 0.06),
            _buildFeatureButton(
              icon: Icons.verified_user_rounded,
              label: 'Verificar reservas',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SupplierVerifyScreen(userId: userId), // Pasamos el userId
                ),
              ),
              primaryColor: primaryColor,
              accentColor: accentColor,
            ),
            SizedBox(height: size.height * 0.03), // Espacio entre botones
            _buildFeatureButton(
              icon: Icons.calendar_month_rounded, // Nuevo ícono
              label: 'Calendario', // Nueva etiqueta
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SupplierCalendarScreen(),
                ),
              ),
              primaryColor: primaryColor,
              accentColor: accentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.business_center_rounded,
            size: 40,
            color: color,
          ),
          const SizedBox(height: 15),
          Text(
            'Bienvenid@',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gestiona tus reservas y más',
            style: GoogleFonts.poppins(
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color primaryColor,
    required Color accentColor,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: primaryColor,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: primaryColor.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

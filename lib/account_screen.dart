import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'change_name_screen.dart';
import 'change_password_screen.dart';

class AccountScreen extends StatelessWidget {
  final String userId;

  const AccountScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
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
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
        child: Column(
          children: [
            SizedBox(height: size.height * 0.04),
            Text(
              'Cuenta',
              style: GoogleFonts.poppins(
                fontSize: size.width * 0.065,
                fontWeight: FontWeight.w600,
                color: const Color.fromRGBO(17, 48, 73, 1),
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: size.height * 0.05),
            _buildOptionCard(
              context: context,
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
            SizedBox(height: size.height * 0.025),
            _buildOptionCard(
              context: context,
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
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final size = MediaQuery.of(context).size;
    const primaryColor = Color.fromRGBO(17, 48, 73, 1);

    return Material(
      borderRadius: BorderRadius.circular(15),
      color: Colors.white,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: EdgeInsets.all(size.width * 0.05),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(size.width * 0.035),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 94, 94, 94).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: size.width * 0.065,
                  color: primaryColor,
                ),
              ),
              SizedBox(width: size.width * 0.05),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.04,
                        fontWeight: FontWeight.w500,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(height: size.height * 0.005),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.033,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: size.width * 0.045,
                color: const Color.fromRGBO(17, 48, 73, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

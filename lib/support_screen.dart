import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromRGBO(17, 48, 73, 1);
    const accentColor = Color.fromRGBO(240, 169, 52, 1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 248, 255),
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: Container(
        color: const Color.fromARGB(255, 243, 248, 255),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SvgPicture.asset(
              'assets/images/Biqoe logo.svg',
              height: 80,
            ),
            const SizedBox(height: 40),
            Text('¿Cómo podemos ayudarte?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor)),
            const SizedBox(height: 16),
            Text(
              'Estamos aquí para resolver cualquier duda o problema que tengas',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 15, color: const Color.fromRGBO(17, 48, 73, 1)),
            ),
            const SizedBox(height: 40),
            _buildContactCard(
              icon: Icons.message_outlined,
              color: const Color(0xFF25D366),
              title: 'Chat en vivo por WhatsApp',
              subtitle: 'Respuesta inmediata',
              onTap: () => _openWhatsApp(context),
            ),
            const SizedBox(height: 20),
            _buildContactCard(
              icon: Icons.email,
              color: accentColor,
              title: 'Escríbenos un correo',
              subtitle: 'soporte@biqoe.com',
              onTap: () => _sendEmail(context), // Agregar función para correo
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Function() onTap,
  }) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color.fromRGBO(17, 48, 73, 1))),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color.fromRGBO(17, 48, 73, 1))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Color.fromRGBO(17, 48, 73, 1), size: 18)
            ],
          ),
        ),
      ),
    );
  }

  void _openWhatsApp(BuildContext context) async {
    try {
      final url = Uri.parse('https://wa.me/584242550208');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw 'No se pudo abrir WhatsApp';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _sendEmail(BuildContext context) async {
    try {
      final url = Uri.parse('mailto:soporte@biqoe.com');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw 'No se pudo abrir el cliente de correo';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

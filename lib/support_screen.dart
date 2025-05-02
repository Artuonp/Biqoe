import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromRGBO(17, 48, 73, 1);
    const accentColor = Color.fromRGBO(240, 169, 52, 1);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 248, 255),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 248, 255),
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: SingleChildScrollView(
        // Permite desplazarse hacia abajo en dispositivos pequeños
        child: Container(
          color: const Color.fromARGB(255, 243, 248, 255),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              SvgPicture.asset(
                'assets/images/Biqoe logo.svg',
                height: 80,
              ),
              const SizedBox(height: 40),
              Text(
                '¿Cómo podemos ayudarte?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Estamos aquí para resolver cualquier duda o problema que tengas',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: const Color.fromRGBO(17, 48, 73, 1),
                ),
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
                onTap: () => _sendEmail(context),
              ),
            ],
          ),
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
                  color: Color.fromARGB(15, color.r.toInt(), color.g.toInt(),
                      color.b.toInt()), // 10% de opacidad
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color.fromRGBO(17, 48, 73, 1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color.fromRGBO(17, 48, 73, 1),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color.fromRGBO(17, 48, 73, 1),
                size: 18,
              ),
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
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'soporte@biqoe.com',
      query: 'subject=Soporte&body=Hola, necesito ayuda con...', // Opcional
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCopyEmailDialog(context);
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.poppins(
                color: const Color.fromRGBO(17, 48, 73, 1),
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.white,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _showCopyEmailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Center(
            child: Text(
              'Cliente de correo no encontrado',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color.fromRGBO(17, 48, 73, 1),
              ),
            ),
          ),
          content: Text(
            'No se encontró un cliente de correo configurado en el dispositivo. Por favor, copie la dirección de correo y envíe un mensaje manualmente.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color.fromRGBO(17, 48, 73, 1),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(
                    const ClipboardData(text: 'soporte@biqoe.com'));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Correo copiado al portapapeles',
                      style: GoogleFonts.poppins(
                        color: const Color.fromRGBO(17, 48, 73, 1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Colors.white,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              child: Text(
                'Copiar correo',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromRGBO(17, 48, 73, 1),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromRGBO(17, 48, 73, 1),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

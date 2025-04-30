import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TÉRMINOS Y CONDICIONES DE BIQOE',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color.fromRGBO(17, 48, 73, 1),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Aceptación de los Términos'),
            _buildSectionText(
              'Al acceder y utilizar la aplicación BIQOE, usted acepta estos Términos y Condiciones de Uso, así como las leyes y regulaciones aplicables dentro del marco legal venezolano. Usted reconoce que es responsable de cumplir con cualquier normativa local pertinente. Si no está de acuerdo con estos términos, no está autorizado para usar la aplicación.',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Descripción del Servicio'),
            _buildSectionText(
              'BIQOE es una plataforma digital diseñada para facilitar la conexión entre usuarios y proveedores de servicios relacionados con comida, entretenimiento, turismo y ocio en Venezuela. Los servicios disponibles en BIQOE incluyen, pero no se limitan a:',
            ),
            _buildBulletPoint(
                'Turismo y Aventuras: Full days, excursiones, tours guiados, visitas culturales y actividades al aire libre como camping y glamping.'),
            _buildBulletPoint(
                'Entretenimiento y Ocio: Entradas a eventos, conciertos, talleres, bares, y actividades como karting y paintball.'),
            _buildBulletPoint(
                'Gastronomía: Reservas en restaurantes, degustaciones y experiencias culinarias.'),
            _buildBulletPoint(
                'Hospedaje: Reservas en hoteles, posadas, cabañas y casas vacacionales.'),
            _buildBulletPoint(
                'Bienestar: Servicios de spa, retiros de relajación y experiencias de bienestar.'),
            _buildSectionText(
              'BIQOE actúa como un intermediario tecnológico, facilitando la búsqueda, comparación y contratación de estos servicios. No es responsable de la ejecución, calidad, disponibilidad o cumplimiento de los servicios ofrecidos por los proveedores, ya que la relación contractual y cualquier obligación surge directamente entre el proveedor y el consumidor.',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Registro y Creación de Cuenta'),
            _buildSectionText(
              'Para acceder a las funcionalidades de BIQOE, deberá registrarse y crear una cuenta proporcionando información veraz y actualizada. Es su responsabilidad mantener la confidencialidad de su contraseña y asegurarse de que ninguna actividad no autorizada se realice en su cuenta. BIQOE asegura que los datos de los usuarios están protegidos mediante sistemas informáticos.',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Uso Apropiado de la Aplicación'),
            _buildSectionText(
              'Usted se compromete a utilizar BIQOE únicamente con fines legales y de forma respetuosa, evitando cualquier conducta que pueda perjudicar a otros usuarios, proveedores o al buen funcionamiento de la aplicación. Esto incluye, pero no se limita a:',
            ),
            _buildBulletPoint(
                'No acosar, ofender o causar molestias a otros usuarios o proveedores.'),
            _buildBulletPoint(
                'No publicar contenido obsceno, ofensivo o que interrumpa la experiencia normal de los usuarios.'),
            _buildBulletPoint(
                'Mantener un comportamiento acorde con las normas de convivencia y buenas costumbres.'),
            _buildSectionText(
              'BIQOE puede incorporar herramientas como geolocalización, notificaciones y enlaces externos para mejorar la experiencia del usuario. Sin embargo, BIQOE no se responsabiliza por el contenido de sitios externos.',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Propiedad Intelectual'),
            _buildSectionText(
              'Todos los contenidos, diseños y elementos de BIQOE, incluyendo textos, gráficos, imágenes, software y otros materiales, son propiedad intelectual de BIQOE o sus licenciantes. Estos están protegidos por derechos de autor y otros derechos de propiedad intelectual, debidamente registrados ante las autoridades correspondientes.',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Edad Mínima Requerida'),
            _buildSectionText(
              'El uso de BIQOE está permitido únicamente para personas mayores de 18 años. Al registrarse, usted declara y garantiza que cumple con este requisito de edad. BIQOE se reserva el derecho de suspender o eliminar cuentas que incumplan esta disposición.',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Limitación de Responsabilidad'),
            _buildSectionText(
              'BIQOE no se responsabiliza por la calidad, puntualidad, disponibilidad, legalidad o idoneidad de los servicios ofrecidos por los proveedores en la plataforma. Todas las transacciones y acuerdos realizados son estrictamente entre el proveedor de servicios y el usuario.',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Modificación de Términos'),
            _buildSectionText(
              'BIQOE se reserva el derecho de modificar estos Términos y Condiciones en cualquier momento. Cualquier cambio será notificado a través de la aplicación o por otros medios razonables, y su uso continuado de la plataforma después de dichos cambios constituye su aceptación de los nuevos términos.',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Ley Aplicable'),
            _buildSectionText(
              'Estos Términos y Condiciones se regirán e interpretarán de acuerdo con las leyes de la República Bolivariana de Venezuela. Cualquier disputa que surja en relación con estos términos será sometida a los tribunales competentes de Venezuela.',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Contacto'),
            _buildSectionText(
              'Para cualquier consulta o aclaración sobre estos términos, puede comunicarse con nosotros a través de los canales de contacto indicados en la aplicación.',
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse('https://privacy.biqoe.com');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: Text(
                  'Política de Privacidad: https://privacy.biqoe.com',
                  style: GoogleFonts.poppins(
                    color: Colors.blue,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: const Color.fromRGBO(17, 48, 73, 1),
      ),
    );
  }

  Widget _buildSectionText(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: const Color.fromRGBO(17, 48, 73, 1),
      ),
      textAlign: TextAlign.justify,
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }
}

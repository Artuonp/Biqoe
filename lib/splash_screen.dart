import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Esta pantalla ahora es 100% visual.
// Ya no recibe 'destinations' ni tiene lógica de Timer.
// La lógica de espera o carga la maneja el 'UpdateChecker' o el 'Router'.
class SplashScreen extends StatelessWidget {
  // Eliminamos 'required this.destinations'
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos MediaQuery para que el logo sea responsivo
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Logo Central
              Image.asset(
                'assets/images/Biqoe logo1.png',
                width: size.width * 0.4, // 40% del ancho de pantalla
                height: size.width * 0.4,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              // Texto inferior
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text(
                  'By Biqono',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 118, 117, 117),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

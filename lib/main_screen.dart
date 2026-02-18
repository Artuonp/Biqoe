import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtener el tamaño de la pantalla
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      body: Stack(
        children: [
          // -----------------------------------------------------------
          // 1. CAPA DE FONDO (IMÁGENES DECORATIVAS)
          // Las ponemos primero para que queden DETRÁS de los botones
          // -----------------------------------------------------------

          // Imagen decorativa (Pájaros)
          Positioned(
            top: screenHeight * 0.05,
            right: screenWidth * 0.05,
            child: SvgPicture.asset(
              'assets/images/Pájaros.svg',
              width: screenWidth * 0.2,
              height: screenHeight * 0.1,
            ),
          ),

          // Imagen decorativa (Caracas)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SvgPicture.asset(
                'assets/images/Caracas.svg',
                width: screenWidth,
                height: screenHeight * 0.25,
              ),
            ),
          ),

          // -----------------------------------------------------------
          // 2. CAPA INTERACTIVA (CONTENIDO Y BOTONES)
          // La ponemos de ULTIMO para que quede ENCIMA de las imágenes
          // y reciba los clics del mouse.
          // -----------------------------------------------------------
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Spacer(), // Empuja el contenido hacia el centro verticalmente

                // Imagen en la parte superior (Logo)
                Center(
                  child: SizedBox(
                    height: screenHeight * 0.15,
                    width: screenWidth * 0.79,
                    child: SvgPicture.asset(
                      'assets/images/Biqoe logo.svg',
                    ),
                  ),
                ),

                const SizedBox(height: 24.0),

                // BOTÓN: Iniciar sesión
                SizedBox(
                  width: screenWidth * 0.8,
                  child: ElevatedButton(
                    onPressed: () {
                      context.push('/login-form');
                    },
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      backgroundColor: const Color.fromRGBO(240, 169, 52, 1),
                    ),
                    child: const Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16.0),

                // BOTÓN: Crear cuenta
                TextButton(
                  onPressed: () {
                    context.push('/register');
                  },
                  child: const Text(
                    'Crear cuenta',
                    style: TextStyle(
                      color: Color.fromRGBO(17, 48, 73, 1),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),

                // BOTÓN: Entrar como visitante
                Center(
                  child: TextButton(
                    onPressed: () {
                      context.push('/guest');
                    },
                    child: const Text(
                      'Entrar como visitante',
                      style: TextStyle(
                        color: Color.fromRGBO(158, 158, 158, 1),
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'register_screen.dart'; // Pantalla de registro
import 'login_screen.dart'; // Pantalla del formulario de inicio de sesión

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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Spacer(), // Empuja el contenido hacia el centro verticalmente
                // Imagen en la parte superior
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
                // Botón de Login
                SizedBox(
                  width: screenWidth * 0.8,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navegar a la pantalla del formulario de login
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const LoginFormScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      backgroundColor: const Color.fromRGBO(
                          240, 169, 52, 1), // Color del botón
                    ),
                    child: const Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1), // Color del texto
                        fontWeight: FontWeight.bold, // Texto en negritas
                        fontFamily: 'Poppins', // Fuente Poppins
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                // Link para crear cuenta
                TextButton(
                  onPressed: () {
                    // Navegar a la pantalla de registro
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text(
                    'Crear cuenta',
                    style: TextStyle(
                      color: Color.fromRGBO(17, 48, 73, 1), // Color del texto
                      fontWeight: FontWeight.bold, // Texto en negritas
                      fontFamily: 'Poppins', // Fuente Poppins
                    ),
                  ),
                ),
                const Spacer(), // Empuja el contenido hacia el centro verticalmente
              ],
            ),
          ),
          // Imagen de Guacamaya en la parte superior derecha
          Positioned(
            top: screenHeight * 0.05,
            right: screenWidth * 0.05,
            child: SvgPicture.asset(
              'assets/images/Pájaros.svg',
              width: screenWidth * 0.2,
              height: screenHeight * 0.1,
            ),
          ),
          // Imagen de Caracas en la parte inferior
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
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _guestLoading = false;

  Future<void> _enterAsGuest() async {
    setState(() => _guestLoading = true);
    bool navigated = false;
    try {
      // Envolver en microtask para capturar TypeError JS de Safari macOS
      // que no es capturable con catch(e) normal en código minificado.
      await Future.microtask(() async {
        try {
          if (kIsWeb) {
            // Intentar persistencia segura — si falla, continuar igual
            for (final p in [
              Persistence.NONE,
              Persistence.SESSION,
              Persistence.LOCAL
            ]) {
              try {
                await FirebaseAuth.instance.setPersistence(p);
                break;
              } catch (_) {}
            }
          }
          final result = await FirebaseAuth.instance.signInAnonymously();
          debugPrint('[Guest] signInAnonymously uid=${result.user?.uid}');
          if (mounted) {
            context.go('/');
            navigated = true;
          }
        } catch (inner) {
          debugPrint('[Guest] inner error: $inner');
          // En Safari macOS puede fallar — navegamos igual al home
          if (mounted) {
            context.go('/');
            navigated = true;
          }
        }
      });
    } catch (outer) {
      // TypeError JS de macOS Safari que escapa del microtask
      debugPrint('[Guest] outer (JS TypeError): $outer');
      if (mounted && !navigated) context.go('/');
    } finally {
      if (mounted) setState(() => _guestLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      body: Stack(
        children: [
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

          // Contenido principal
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Spacer(),

                // Logo
                Center(
                  child: SizedBox(
                    height: screenHeight * 0.15,
                    width: screenWidth * 0.79,
                    child: SvgPicture.asset('assets/images/Biqoe logo.svg'),
                  ),
                ),

                const SizedBox(height: 24.0),

                // Botón: Iniciar sesión
                SizedBox(
                  width: screenWidth * 0.8,
                  child: ElevatedButton(
                    onPressed: () => context.push('/login-form'),
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      backgroundColor: const Color.fromRGBO(240, 169, 52, 1),
                    ),
                    child: const Text(
                      'Iniciar sesión',
                      style: TextStyle(
                          color: Color.fromRGBO(17, 48, 73, 1),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins'),
                    ),
                  ),
                ),

                const SizedBox(height: 16.0),

                // Botón: Crear cuenta
                TextButton(
                  onPressed: () => context.push('/register'),
                  child: const Text(
                    'Crear cuenta',
                    style: TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins'),
                  ),
                ),

                // Botón: Entrar como visitante — llama signInAnonymously directamente
                Center(
                  child: _guestLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color.fromRGBO(158, 158, 158, 1)),
                        )
                      : TextButton(
                          onPressed: _enterAsGuest,
                          child: const Text(
                            'Entrar como visitante',
                            style: TextStyle(
                                color: Color.fromRGBO(158, 158, 158, 1),
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold),
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

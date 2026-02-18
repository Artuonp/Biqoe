import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart'; // Importamos GoRouter

class LoginFormScreen extends StatefulWidget {
  const LoginFormScreen({super.key});

  @override
  LoginFormScreenState createState() => LoginFormScreenState();
}

class LoginFormScreenState extends State<LoginFormScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _login() async {
    try {
      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();

      if (email.isEmpty) {
        _showErrorMessage('Por favor, ingrese su correo electrónico.');
        return;
      }

      if (password.isEmpty) {
        _showErrorMessage('Por favor, ingrese su contraseña.');
        return;
      }

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (userCredential.user != null) {
        // CAMBIO IMPORTANTE:
        // No verificamos emailVerified aquí para no bloquear el acceso si no es estricto.
        // Si quieres obligar verificación, descomenta el if/else.

        // Simplemente vamos al Home. El Router verifica el usuario.
        context.go('/');
      }
    } on FirebaseAuthException catch (e) {
      // Manejo de errores simplificado
      String msg = 'Ocurrió un error inesperado.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        msg = 'Correo o contraseña incorrectos.';
      } else if (e.code == 'invalid-email') {
        msg = 'El formato del correo no es válido.';
      } else if (e.code == 'user-disabled') {
        msg = 'Esta cuenta ha sido deshabilitada.';
      }

      if (mounted) _showErrorMessage(msg);
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showErrorMessage(
          'Escribe tu correo en el campo de arriba para recuperarla.');
      return;
    }

    try {
      // Navegamos a la pantalla de reset pasando el email
      // Nota: Debemos registrar esta ruta en app_router.dart
      context.push('/forgot-password', extra: email);
    } catch (e) {
      _showErrorMessage('Error al navegar: $e');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await GoogleSignIn().signOut(); // Forzar selección de cuenta
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) return; // Usuario canceló

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      if (!mounted) return;

      if (userCredential.user != null) {
        String userId = userCredential.user!.uid;

        // Verificamos si existe en Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          if (!mounted) return;
          context.go('/'); // Navegación exitosa al Home
        } else {
          await _auth.signOut();
          if (mounted) {
            _showErrorMessage(
                'La cuenta de Google no está registrada en la aplicación.');
          }
        }
      }
    } catch (e) {
      debugPrint('Error Google Sign In: $e');
      if (mounted) _showErrorMessage('Error al iniciar sesión con Google.');
    }
  }

  Future<void> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.biqoe.app.SiwA',
          redirectUri: Uri.parse(
            'https://biqoe-app.firebaseapp.com/__/auth/handler',
          ),
        ),
      );

      final oAuthProvider = OAuthProvider("apple.com");
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (!mounted) return;

      if (userCredential.user != null) {
        String userId = userCredential.user!.uid;
        final userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          if (!mounted) return;
          context.go('/'); // Navegación exitosa al Home
        } else {
          await _auth.signOut();
          if (mounted) {
            _showErrorMessage('La cuenta de Apple no está registrada.');
          }
        }
      }
    } catch (e) {
      debugPrint('Error Apple Sign In: $e');
      if (mounted) _showErrorMessage('Error al iniciar sesión con Apple.');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16.0),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 247, 254),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color.fromRGBO(17, 48, 73, 1)),
          onPressed: () {
            // CAMBIO: Usamos context.pop() de GoRouter
            if (context.canPop()) {
              context.pop();
            } else {
              // Si no puede volver (ej: recarga web), redirigir a login
              context.go('/login');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
              const Center(
                child: Text(
                  'Inicio de sesión',
                  style: TextStyle(
                    fontSize: 32.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                    color: Color.fromRGBO(17, 48, 73, 1),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),

              // CAMPO EMAIL
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Correo electrónico',
                  border: UnderlineInputBorder(),
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color.fromRGBO(17, 48, 73, 1),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Color.fromRGBO(17, 48, 73, 1)),
                  ),
                ),
                style: const TextStyle(fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 16.0),

              // CAMPO PASSWORD
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Contraseña',
                  border: UnderlineInputBorder(),
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color.fromRGBO(17, 48, 73, 1),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Color.fromRGBO(17, 48, 73, 1)),
                  ),
                ),
                style: const TextStyle(fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 24.0),

              // BOTÓN LOGIN
              Center(
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 100.0, vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                  ),
                  child: const Text('Iniciar sesión',
                      style: TextStyle(
                          color: Colors.white, fontFamily: 'Poppins')),
                ),
              ),
              const SizedBox(height: 16.0),

              // BOTONES SOCIALES
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: SvgPicture.asset(
                        'assets/images/Google logo 2.svg',
                        width: 35.0,
                        height: 35.0,
                      ),
                      onPressed: signInWithGoogle,
                    ),
                    const SizedBox(width: 16.0),
                    IconButton(
                      icon: Image.asset(
                        'assets/images/Apple logo 2.png',
                        width: 35.0,
                        height: 35.0,
                      ),
                      onPressed: signInWithApple,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5.0),

              // BOTÓN RECUPERAR CONTRASEÑA
              Center(
                child: TextButton(
                  onPressed: _sendPasswordResetEmail,
                  child: const Text(
                    'Recuperación de contraseña',
                    style: TextStyle(
                      color: Color.fromRGBO(17, 48, 73, 1),
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.05),
            ],
          ),
        ),
      ),
    );
  }
}

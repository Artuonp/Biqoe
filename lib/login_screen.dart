import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'search_screen.dart';
import 'password_reset_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'guest_screen.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      String email = _emailController.text;
      String password = _passwordController.text;

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
        if (userCredential.user!.emailVerified) {
          String userId = userCredential
              .user!.uid; // Obtener el userId del usuario autenticado
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SearchScreen(
                destinations: const [],
                userId: userId, // Pasar el userId requerido
              ),
            ),
          );
        } else {
          await _auth.signOut();
          _showErrorMessage(
              'Por favor, verifica tu correo electrónico antes de iniciar sesión.');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
      } else if (e.code == 'wrong-password') {
      } else if (e.code == 'invalid-email') {
      } else if (e.code == 'user-disabled') {
      } else if (e.code == 'too-many-requests') {
      } else if (e.code == 'operation-not-allowed') {
      } else {}

      if (!mounted) return;

      _showErrorMessage('Contraseña o correo incorrecto. Intenta otra vez.');
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    String email = _emailController.text;

    if (email.isEmpty) {
      _showErrorMessage('Escribe tu correo.');
      return;
    }

    try {
      _auth.setLanguageCode('es');
      await _auth.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PasswordResetScreen(email: email),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showErrorMessage(
          'Error: ${e.message ?? 'Ocurrió un error inesperado.'}');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await GoogleSignIn().signOut();
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        _showErrorMessage('Inicio de sesión con Google cancelado.');
        return;
      }

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

        final userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SearchScreen(
                destinations: const [],
                userId: userId,
              ),
            ),
          );
        } else {
          await _auth.signOut();
          _showErrorMessage(
              'La cuenta de Google no está registrada en la aplicación.');
        }
      }
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('FirebaseAuthException: $e');
      debugPrintStack(stackTrace: stack);
      _showErrorMessage(
          'Error al iniciar sesión con Google: ${e.message ?? 'Ocurrió un error inesperado.'}');
    } catch (e, stack) {
      debugPrint('Error: $e');
      debugPrintStack(stackTrace: stack);
      _showErrorMessage('Error al iniciar sesión con Google: ${e.toString()}');
    }
  }

  // filepath:
  Future<void> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        // Necesario para Android/Web:
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.biqoe.app.SiwA', // Tu Service ID exacto
          redirectUri: Uri.parse(
            'https://biqoe-app.firebaseapp.com/__/auth/handler', // Debe coincidir con tu intent-filter
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
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SearchScreen(
                destinations: const [],
                userId: userId,
              ),
            ),
          );
        } else {
          await _auth.signOut();
          if (!mounted) return;
          _showErrorMessage(
            'La cuenta de Apple no está registrada en la aplicación.',
          );
        }
      }
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('FirebaseAuthException: $e');
      debugPrintStack(stackTrace: stack);
      _showErrorMessage('Error al iniciar sesión con Apple');
    } catch (e, stack) {
      debugPrint('Error: $e');
      debugPrintStack(stackTrace: stack);
      _showErrorMessage('Error al iniciar sesión con Apple');
    }
  }

  void _showErrorMessage(String message) {
    final snackBar = SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
      appBar: AppBar(
        backgroundColor:
            const Color.fromARGB(255, 243, 247, 254), // Fondo del AppBar
        elevation: 0, // Sin sombra
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color.fromRGBO(17, 48, 73, 1)),
          onPressed: () {
            Navigator.of(context).pop(); // Regresa a la pantalla anterior
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
              const SizedBox(height: 8.0),
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
              const SizedBox(height: 8.0),
              TextField(
                controller: _passwordController,
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
                      ), // Espacio entre los botones
                      onPressed: signInWithApple,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5.0),
              Center(
                child: TextButton(
                  onPressed: _sendPasswordResetEmail,
                  child: Text(
                    'Recuperación de contraseña',
                    style: TextStyle(
                      color: const Color.fromRGBO(17, 48, 73, 1),
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => GuestScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Entrar como visitante',
                    style: TextStyle(
                      color: Color.fromRGBO(17, 48, 73, 1),
                      fontFamily: 'Poppins',
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

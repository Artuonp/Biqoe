import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🔥 IMPORTANTE PARA ACTUALIZAR TOKEN

class LoginFormScreen extends StatefulWidget {
  const LoginFormScreen({super.key});

  @override
  LoginFormScreenState createState() => LoginFormScreenState();
}

class LoginFormScreenState extends State<LoginFormScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  // ── Persistencia segura para web ────────────────────────────────────────
  Future<void> _setSafePersistenceForEmailLogin() async {
    if (kIsWeb) {
      try {
        await _auth.setPersistence(Persistence.SESSION);
        debugPrint('[Auth] Persistencia web: SESSION');
      } catch (e) {
        debugPrint('[Auth] No se pudo setear persistencia: $e');
      }
    }
  }

  // ── Helper: consulta isSupplier, actualiza Token → navega al destino ────
  Future<void> _navigateAfterLogin(String userId) async {
    debugPrint('[Auth] _navigateAfterLogin uid=$userId');
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .get();

      if (!mounted) return;
      if (!userDoc.exists) {
        debugPrint(
            '[Auth] Usuario no encontrado en Firestore, cerrando sesión');
        await _auth.signOut();
        _showErrorMessage(
            'La cuenta no está registrada. Por favor regístrate primero.');
        return;
      }

      // 🔥 FIX: Actualizar el Device Token de forma segura (sin bloquear el login)
      try {
        String? deviceToken;
        if (!kIsWeb) {
          deviceToken = await FirebaseMessaging.instance
              .getToken()
              .timeout(const Duration(seconds: 4));
        }
        if (deviceToken != null && deviceToken.isNotEmpty) {
          // Lo actualizamos en segundo plano
          FirebaseFirestore.instance.collection('usuarios').doc(userId).update({
            'deviceToken': deviceToken,
          }).catchError((_) {});
        }
      } catch (e) {
        debugPrint(
            "Advertencia: Fallo al actualizar device token en login: $e");
      }

      if (!mounted) return;
      final bool isSupplier = userDoc.data()?['isSupplier'] == true;
      debugPrint('[Auth] isSupplier=$isSupplier → navegando');
      context.go(isSupplier ? '/supplier/dashboard' : '/');
    } catch (e, stack) {
      debugPrint('[Auth] Error en _navigateAfterLogin: $e\n$stack');
      if (mounted) context.go('/');
    }
  }

  // ── Login con email/contraseña ───────────────────────────────────────────
  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      _showErrorMessage('Por favor, ingrese su correo electrónico.');
      return;
    }
    if (password.isEmpty) {
      _showErrorMessage('Por favor, ingrese su contraseña.');
      return;
    }

    try {
      await _setSafePersistenceForEmailLogin();
      debugPrint('[Auth] Intentando email login: $email');

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('[Auth] Email login OK uid=${userCredential.user?.uid}');

      if (!mounted) return;
      if (userCredential.user != null) {
        await _navigateAfterLogin(userCredential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
          '[Auth] FirebaseAuthException code=${e.code} msg=${e.message}');
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
    } catch (e, stack) {
      debugPrint('[Auth] Error inesperado en _login: $e\n$stack');
      if (mounted) {
        _showErrorMessage(
            'Tu navegador bloqueó el inicio de sesión. Desactiva el bloqueo de rastreo en Safari.');
      }
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorMessage(
          'Escribe tu correo en el campo de arriba para recuperar la contraseña.');
      return;
    }
    try {
      context.push('/forgot-password', extra: email);
    } catch (e) {
      _showErrorMessage('Error al navegar: $e');
    }
  }

  // ── Login con Google ─────────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    debugPrint('[Auth] signInWithGoogle iniciado. kIsWeb=$kIsWeb');
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        debugPrint('[Auth] Web: usando signInWithPopup(GoogleAuthProvider)');
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        debugPrint('[Auth] Móvil: usando GoogleSignIn nativo');
        final credential = await _googleSignInNative();
        if (credential == null) {
          debugPrint('[Auth] Google sign-in cancelado o falló en nativo');
          return;
        }
        userCredential = await _auth.signInWithCredential(credential);
      }

      if (!mounted) return;
      if (userCredential.user != null) {
        await _navigateAfterLogin(userCredential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
          '[Auth] FirebaseAuthException Google: code=${e.code} msg=${e.message}');
      if (mounted) {
        _showErrorMessage(
            'Error Google [${e.code}]: ${e.message ?? "Intenta de nuevo."}');
      }
    } catch (e, stack) {
      debugPrint('[Auth] Error en signInWithGoogle: $e\n$stack');
      if (mounted) {
        _showErrorMessage(
            'Ocurrió un error al iniciar sesión con Google. Intenta más tarde.');
      }
    }
  }

  Future<AuthCredential?> _googleSignInNative() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      return GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
    } catch (e) {
      debugPrint('[Auth] _googleSignInNative error: $e');
      return null;
    }
  }

  // ── Login con Apple ──────────────────────────────────────────────────────
  Future<void> signInWithApple() async {
    debugPrint('[Auth] signInWithApple iniciado. kIsWeb=$kIsWeb');
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        debugPrint(
            '[Auth] Web: usando signInWithPopup(OAuthProvider apple.com)');
        final provider = OAuthProvider('apple.com');
        provider.addScope('email');
        provider.addScope('name');
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        debugPrint('[Auth] Móvil: usando SignInWithApple nativo');
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          webAuthenticationOptions: WebAuthenticationOptions(
            clientId: 'com.biqoe.app.SiwA',
            redirectUri:
                Uri.parse('https://biqoe-app.firebaseapp.com/__/auth/handler'),
          ),
        );
        final oAuthProvider = OAuthProvider('apple.com');
        final credential = oAuthProvider.credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      if (!mounted) return;
      if (userCredential.user != null) {
        await _navigateAfterLogin(userCredential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
          '[Auth] FirebaseAuthException Apple: code=${e.code} msg=${e.message}');
      if (mounted) {
        _showErrorMessage(
            'Error Apple [${e.code}]: ${e.message ?? "Intenta de nuevo."}');
      }
    } catch (e, stack) {
      debugPrint('[Auth] Error en signInWithApple: $e\n$stack');
      if (mounted) {
        _showErrorMessage(
            'Ocurrió un error al iniciar sesión con Apple. Intenta más tarde.');
      }
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
            if (context.canPop()) {
              context.pop();
            } else {
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
                      color: Color.fromRGBO(17, 48, 73, 1)),
                ),
              ),
              const SizedBox(height: 20.0),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Correo electrónico',
                  border: UnderlineInputBorder(),
                  enabledBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Color.fromRGBO(17, 48, 73, 1))),
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Contraseña',
                  border: UnderlineInputBorder(),
                  enabledBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Color.fromRGBO(17, 48, 73, 1))),
                ),
              ),
              const SizedBox(height: 24.0),
              Center(
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 100.0, vertical: 16.0),
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
                      ),
                      onPressed: signInWithApple,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5.0),
              Center(
                child: TextButton(
                  onPressed: _sendPasswordResetEmail,
                  child: const Text('Recuperación de contraseña',
                      style: TextStyle(
                          color: Color.fromRGBO(17, 48, 73, 1),
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

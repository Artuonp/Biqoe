import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io' show Platform;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  RegisterScreenState createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // Variable para el código de país (únicamente Venezuela en este caso)
  String selectedCountryCode = "+58";

  // Validar correo electrónico (solo Gmail, Outlook o Yahoo)
  bool isValidEmail(String email) {
    const allowedDomains = [
      'gmail.com',
      'outlook.com',
      'yahoo.com',
      'icloud.com',
      'hotmail.com'
    ];
    for (String domain in allowedDomains) {
      if (email.endsWith(domain)) return true;
    }
    return false;
  }

  // Validar contraseña (mínimo 7 caracteres, al menos una letra y un número)
  bool isValidPassword(String password) {
    bool hasLetter = password.contains(RegExp(r'[A-Za-z]'));
    bool hasNumber = password.contains(RegExp(r'[0-9]'));
    return password.length >= 7 && hasLetter && hasNumber;
  }

  // Validar número de celular según lo solicitado
  bool isValidPhone(String phone) {
    // Verificar que el celular contenga únicamente números
    if (!RegExp(r'^\d+$').hasMatch(phone)) return false;

    // Verificar que tenga 10 u 11 dígitos
    if (phone.length != 10 && phone.length != 11) return false;

    // Prefijos permitidos
    List<String> allowedPrefixes = [
      "0424",
      "424",
      "0426",
      "426",
      "0416",
      "416",
      "0414",
      "414",
      "0412",
      "412"
    ];
    bool validPrefix = false;
    for (String prefix in allowedPrefixes) {
      if (phone.startsWith(prefix)) {
        validPrefix = true;
        break;
      }
    }
    if (!validPrefix) return false;

    // Verificar que no se repita cinco o más dígitos consecutivos (por ejemplo: 55555)
    if (RegExp(r'(\d)\1{4,}').hasMatch(phone)) return false;

    // Verificar que no haya 5 dígitos consecutivos en secuencia ascendente (por ejemplo: 23456)
    for (int i = 0; i <= phone.length - 5; i++) {
      String substring = phone.substring(i, i + 5);
      bool isSequential = true;
      for (int j = 0; j < 4; j++) {
        int currentDigit = int.parse(substring[j]);
        int nextDigit = int.parse(substring[j + 1]);
        if (nextDigit - currentDigit != 1) {
          isSequential = false;
          break;
        }
      }
      if (isSequential) return false;
    }
    return true;
  }

// Solicitar permisos de notificaciones
  Future<bool> requestNotificationPermissions() async {
    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      return true;
    } else {
      _showErrorMessage(
          'Debes aceptar recibir notificaciones para continuar con el registro.');
      return false;
    }
  }

  // Función para registrar un nuevo usuario

  Future<void> register() async {
    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String phone = phoneController.text.trim();

    // Validar los campos de entrada
    if (name.isEmpty) {
      _showErrorMessage('El nombre no puede estar vacío');
      return;
    }

    if (!isValidEmail(email)) {
      _showErrorMessage(
          'Únicamente se acepta Gmail, Outlook, Icloud, Hotmail o Yahoo');
      return;
    }

    if (!isValidPassword(password)) {
      _showErrorMessage(
          'La contraseña debe ser de 7 o más dígitos con mínimo una letra y un número');
      return;
    }

    if (!isValidPhone(phone)) {
      _showErrorMessage('Ingrese un número de celular válido');
      return;
    }

    // Solicitar permisos de notificaciones
    bool notificationsAllowed = await requestNotificationPermissions();
    if (!notificationsAllowed) {
      return;
    }

    // Esperar APNS token en iOS antes de pedir el FCM token
    if (Platform.isIOS) {
      NotificationSettings settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      debugPrint('Permiso de notificaciones: ${settings.authorizationStatus}');
      int retries = 0;
      String? apnsToken;
      do {
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        debugPrint('Intento $retries, APNS token: $apnsToken');
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 2));
        }
        retries++;
      } while (apnsToken == null && retries < 5);
      if (apnsToken == null) {
        _showErrorMessage(
            'No se pudo obtener el token de notificaciones de Apple.\n');
        return;
      }
    }

    try {
      // Verificar si el correo ya está registrado

      // Intentar crear el usuario con Firebase Authentication
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Establecer el idioma del correo de verificación
      await FirebaseAuth.instance.setLanguageCode('es');

      // Enviar correo de verificación
      await userCredential.user!.sendEmailVerification();

      // Obtener el UID del usuario
      String uid = userCredential.user!.uid;

      // Obtener el token del dispositivo
      String? deviceToken = await FirebaseMessaging.instance.getToken();

      // Agregar el usuario a la colección de Firestore
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'name': name,
        'isAdmin': false,
        'isSupplier': false,
        'email': email,
        'verified': false, // Campo para verificar el correo
        'celular': phone,
        'deviceToken': deviceToken, // Guardar el token del dispositivo
      });

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );

      _showSuccessMessage(
          'Registro exitoso. Por favor, verifica tu correo electrónico.');
    } on FirebaseAuthException catch (e) {
      // Manejar errores específicos de Firebase Authentication
      if (e.code == 'email-already-in-use') {
        _showErrorMessage('El correo ya está en uso. Intenta con otro.');
      } else if (e.code == 'weak-password') {
        _showErrorMessage('La contraseña es demasiado débil.');
      } else if (e.code == 'invalid-email') {
        _showErrorMessage('El correo electrónico no es válido.');
      } else if (e.code == 'operation-not-allowed') {
        _showErrorMessage(
            'El registro con correo electrónico y contraseña no está habilitado.');
      } else if (e.code == 'network-request-failed') {
        _showErrorMessage(
            'Error de red. Por favor, verifica tu conexión a internet.');
      } else {
        _showErrorMessage(
            'Ocurrió un error durante el registro. Inténtalo de nuevo.');
      }
    } catch (e) {
      _showErrorMessage(
          'Ocurrió un error inesperado. Por favor, inténtalo de nuevo.');
    }
  }

  // Función para autenticarse con Google
  /// 1️⃣ Helper para comprobar en Firestore si un email ya está registrado
  Future<bool> emailYaRegistrado(String email) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// 2️⃣ Método completo de registro con Google, usando el helper anterior
  Future<void> signInWithGoogle() async {
    String phone = phoneController.text.trim();
    if (!isValidPhone(phone)) {
      _showErrorMessage('Ingrese un número de celular válido');
      return;
    }

    // Solicitar permisos de notificaciones
    bool notificationsAllowed = await requestNotificationPermissions();
    if (!notificationsAllowed) return;

    try {
      // Asegurarse de empezar limpio
      await GoogleSignIn().signOut();

      // 1) Selección de cuenta Google
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _showErrorMessage('Registro con Google cancelado.');
        return;
      }

      final email = googleUser.email;

      // 2) Comprueba en Firestore si ya existe ese email
      if (await emailYaRegistrado(email)) {
        _showErrorMessage('Esta cuenta de Google ya está siendo utilizada');
        return;
      }

      // 3) Autenticación en Firebase
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // 4) Guarda en Firestore
      String uid = userCredential.user!.uid;
      String? deviceToken = await FirebaseMessaging.instance.getToken();
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'name': googleUser.displayName,
        'isAdmin': false,
        'isSupplier': false,
        'email': email,
        'verified': true,
        'celular': phone,
        'deviceToken': deviceToken,
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      _showSuccessMessage('Registro exitoso con Google.');
    } catch (e) {
      _showErrorMessage(
          'Ocurrió un error al iniciar sesión con Google. Intenta más tarde');
    }
  }

  Future<void> signInWithApple() async {
    String phone = phoneController.text.trim();
    if (!Platform.isIOS) {
      if (!isValidPhone(phone)) {
        _showErrorMessage('Ingrese un número de celular válido');
        return;
      }
    }

    // Solicitar permisos de notificaciones
    bool notificationsAllowed = await requestNotificationPermissions();
    if (!notificationsAllowed) return;

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        // Solo necesario en Android/Web:
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

      // Inicia sesión en Firebase
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Verifica si el email ya está registrado
      final email = userCredential.user?.email ?? appleCredential.email;
      if (email == null) {
        _showErrorMessage('No se pudo obtener el correo de Apple ID.');
        return;
      }
      if (await emailYaRegistrado(email)) {
        _showErrorMessage('Esta cuenta de Apple ya está siendo utilizada');
        return;
      }

      // Guarda en Firestore
      String uid = userCredential.user!.uid;
      String? deviceToken = await FirebaseMessaging.instance.getToken();
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'name':
            appleCredential.givenName ?? userCredential.user?.displayName ?? '',
        'isAdmin': false,
        'isSupplier': false,
        'email': email,
        'verified': true,
        'celular': Platform.isIOS ? '' : phone,
        'deviceToken': deviceToken,
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      _showSuccessMessage('Registro exitoso con Apple.');
    } catch (e) {
      _showErrorMessage(
          'Ocurrió un error al iniciar sesión con Apple. Intenta más tarde');
    }
  }

  // Función para mostrar el mensaje de error con SnackBar
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

  // Función para mostrar el mensaje de éxito con SnackBar
  void _showSuccessMessage(String message) {
    final snackBar = SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: Colors.green,
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
      backgroundColor: const Color.fromARGB(255, 243, 247, 254), // Fondo claro
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
                child: Column(
                  children: [
                    Text(
                      'Registro de cuenta',
                      style: TextStyle(
                        fontSize: 32.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(17, 48, 73, 1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20.0),
              const SizedBox(height: 8.0),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'Nombre',
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
              TextField(
                controller: emailController,
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
              // Campo para el número de celular con selector de bandera
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 243, 247, 254),
                      border: Border.all(
                          color: const Color.fromARGB(255, 243, 247, 254)),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: const Text(
                      "🇻🇪 +58",
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Celular',
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
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: passwordController,
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
                  onPressed: register,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 100.0, vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                  ),
                  child: const Text('Crear cuenta',
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
                    const SizedBox(width: 16.0), // Espacio entre los botones
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
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  },
                  child: const Text(
                    'Iniciar sesión',
                    style: TextStyle(
                        color: Color.fromRGBO(17, 48, 73, 1),
                        fontFamily: 'Poppins'),
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

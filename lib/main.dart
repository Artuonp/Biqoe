import 'package:biqoe/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:io';

import 'splash_screen.dart';
import 'main_screen.dart';
import 'booking_provider.dart';
import 'verify_screen.dart';
import 'supplier_verify_screen.dart';

final List<String> destinations = [
  'Destino 1',
  'Destino 2',
  'Destino 3',
];

final Logger logger = Logger();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  logger.i(
      'Notificación recibida en segundo plano: ${message.notification?.title}');
  _handleNotificationNavigation(message);
}

void _handleNotificationNavigation(RemoteMessage message) async {
  final user = FirebaseAuth.instance.currentUser;
  final rol = message.data['rol'];

  if (user == null) {
    navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return;
  }

  final userId = user.uid;

  if (rol == 'supplier') {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => SupplierVerifyScreen(userId: userId)),
    );
  } else if (rol == 'admin') {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => VerifyScreen(userId: userId)),
    );
  }
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logger.e('FlutterError: ${details.exceptionAsString()}');
      if (details.stack != null) {
        logger.e(details.stack.toString());
      }
    };

    try {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      if (Platform.isIOS) {
        await FirebaseMessaging.instance.setAutoInitEnabled(true);
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      await Hive.initFlutter();
      await Hive.openBox<Map>('saved_destinations');

      setupFirebaseMessaging();

      FirebaseMessaging.instance
          .getInitialMessage()
          .then((RemoteMessage? message) {
        if (message != null) {
          _handleNotificationNavigation(message);
        }
      });

      runApp(MyApp(destinations: destinations));
    } catch (e, stack) {
      logger.e('Error en main: $e');
      logger.e(stack.toString());
    }
  }, (error, stack) {
    logger.e('Error fuera de zona: $error');
    logger.e(stack.toString());
  });
}

void setupFirebaseMessaging() {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
  );

  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  if (Platform.isIOS) {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    AppleNotification? ios = message.notification?.apple;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            icon: android.smallIcon,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }

    if (notification != null && ios != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(),
        ),
      );
    }

    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color.fromARGB(254, 255, 249, 255),
          title: Text(
            notification?.title ?? 'Notificación',
            style: const TextStyle(
              color: Color.fromRGBO(17, 48, 73, 1),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            notification?.body ?? 'Sin contenido',
            style: const TextStyle(
              color: Color.fromRGBO(17, 48, 73, 1),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await Future.delayed(const Duration(milliseconds: 100));

                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final userId = user.uid;
                  final rol = message.data['rol'];
                  if (rol == 'supplier') {
                    navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (context) =>
                            SupplierVerifyScreen(userId: userId),
                      ),
                    );
                  } else if (rol == 'admin') {
                    navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (context) => VerifyScreen(userId: userId),
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Ok',
                style: TextStyle(
                  color: Color.fromRGBO(17, 48, 73, 1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNavigation);

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .update({'deviceToken': newToken});
        logger.i('Token actualizado en Firestore: $newToken');
      } catch (e) {
        logger.e('Error al actualizar el token en Firestore: $e');
      }
    }
  });
}

class MyApp extends StatelessWidget {
  final List<String> destinations;

  const MyApp({super.key, required this.destinations});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => BookingProvider(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'biqoe',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'),
        ],
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(1.0)),
            child: child!,
          );
        },
        home: UpdateChecker(destinations: destinations),
      ),
    );
  }
}

/// Nueva capa: Verifica versión antes de SplashWrapper
class UpdateChecker extends StatefulWidget {
  final List<String> destinations;

  const UpdateChecker({super.key, required this.destinations});

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  bool _loading = true;
  bool _needsUpdate = false;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    await remoteConfig.fetchAndActivate();

    final minRequiredVersion = remoteConfig.getInt('min_required_version');
    const currentVersion = 38;

    if (currentVersion < minRequiredVersion) {
      setState(() {
        _needsUpdate = true;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SplashScreen(
        destinations: [],
      );
    }

    if (_needsUpdate) {
      return Scaffold(
        backgroundColor: Colors.black54,
        body: Center(
          child: AlertDialog(
            backgroundColor: Color.fromARGB(250, 255, 255, 255),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/Nueva.jpeg'),
                const SizedBox(height: 16),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Color.fromRGBO(17, 48, 73, 1)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromRGBO(17, 48, 73, 1),
                ),
                onPressed: () async {
                  final url = Platform.isAndroid
                      ? 'https://play.google.com/store/apps/details?id=com.biqoe.app&pcampaignid=web_share'
                      : 'https://apps.apple.com/ve/app/biqoe/id6746291495';
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Text(
                  'Actualizar',
                  style: TextStyle(color: Colors.white),
                ),
              )
            ],
          ),
        ),
      );
    }

    return SplashScreen(destinations: widget.destinations);
  }
}

import 'package:flutter/foundation.dart'; // IMPORTANTE: Reemplaza a dart:io
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:url_launcher/url_launcher.dart';
import '../splash_screen.dart'; // Asegúrate de tener el splash visual aquí

class UpdateChecker extends StatefulWidget {
  final Widget child;

  const UpdateChecker({super.key, required this.child});

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
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      await remoteConfig.fetchAndActivate();

      final minRequiredVersion = remoteConfig.getInt('min_required_version');
      const currentVersion = 46; // TU VERSIÓN ACTUAL FIJA

      if (currentVersion < minRequiredVersion) {
        if (mounted) {
          setState(() {
            _needsUpdate = true;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
    } catch (e) {
      // Si falla (ej. sin internet), dejamos pasar
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SplashScreen(); // Tu Splash visual
    }

    if (_needsUpdate) {
      // TU DIÁLOGO ORIGINAL RESTAURADO EXACTAMENTE
      return Scaffold(
        backgroundColor: Colors.black54,
        body: Center(
          child: AlertDialog(
            backgroundColor: const Color.fromARGB(250, 255, 255, 255),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/Nueva.jpeg'), // TU IMAGEN
                const SizedBox(height: 16),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Color.fromRGBO(17, 48, 73, 1)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(17, 48, 73, 1),
                ),
                onPressed: () async {
                  // CAMBIO AQUÍ: Usamos defaultTargetPlatform en lugar de Platform.isAndroid
                  final url = defaultTargetPlatform == TargetPlatform.android
                      ? 'https://play.google.com/store/apps/details?id=com.biqoe.app&pcampaignid=web_share'
                      : 'https://apps.apple.com/ve/app/biqoe/id6746291495';
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text(
                  'Actualizar',
                  style: TextStyle(color: Colors.white),
                ),
              )
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}

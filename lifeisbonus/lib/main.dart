import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: '2fb2536b99bf76097001386b2837c5ce',
  );
  KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseFirestore.instance.clearPersistence();
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  runApp(const LifeIsBonusApp());
}

class LifeIsBonusApp extends StatelessWidget {
  const LifeIsBonusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '인생은 보너스',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansKrTextTheme(),
      ),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  Future<bool> _shouldShowIntro() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('introHideUntil');
    if (raw == null || raw.trim().isEmpty) {
      return true;
    }
    final hideUntil = DateTime.tryParse(raw);
    if (hideUntil == null) {
      return true;
    }
    return DateTime.now().isAfter(hideUntil);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _shouldShowIntro(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFF4E6),
                    Color(0xFFFCE7F1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A3D)),
                  strokeWidth: 3,
                ),
              ),
            ),
          );
        }
        final showIntro = snapshot.data ?? true;
        if (showIntro) {
          return const IntroScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

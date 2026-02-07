import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';
import 'app_theme.dart';

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
  await AppThemeController.load();
  runApp(const LifeIsBonusApp());
}

class LifeIsBonusApp extends StatelessWidget {
  const LifeIsBonusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '인생은 보너스',
          theme: ThemeData(
            useMaterial3: true,
            textTheme: GoogleFonts.notoSansKrTextTheme(),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            textTheme: GoogleFonts.notoSansKrTextTheme(),
          ),
          themeMode: mode,
          home: const _LaunchGate(),
        );
      },
    );
  }
}

class _LaunchGate extends StatelessWidget {
  const _LaunchGate();

  Future<bool> _shouldShowIntro() async {
    final prefs = await SharedPreferences.getInstance();
    final hideUntil = prefs.getString('introHideUntil');
    if (hideUntil == null) {
      return true;
    }
    final parsed = DateTime.tryParse(hideUntil);
    if (parsed == null) {
      return true;
    }
    return DateTime.now().isAfter(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _shouldShowIntro(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final showIntro = snapshot.data ?? true;
        return showIntro ? const IntroScreen() : const LoginScreen();
      },
    );
  }
}

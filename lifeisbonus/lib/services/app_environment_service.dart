import 'package:flutter/services.dart';

class AppEnvironmentService {
  AppEnvironmentService._();

  static const MethodChannel _channel = MethodChannel(
    'lifeisbonus/app_environment',
  );

  static Future<bool> isIosSimulator() async {
    try {
      return await _channel.invokeMethod<bool>('isSimulator') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

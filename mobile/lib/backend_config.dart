import 'package:shared_preferences/shared_preferences.dart';

class BackendConfig {
  static const defaultBaseUrl = String.fromEnvironment(
    'LION_BRO_API_URL',
    defaultValue: 'http://129.154.35.105:8080',
  );

  static Future<String> loadBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('lion_bro_api_url') ?? defaultBaseUrl;
  }

  static Future<void> saveBaseUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('lion_bro_api_url', url.trim().replaceAll(RegExp(r'/+$'), ''));
  }
}

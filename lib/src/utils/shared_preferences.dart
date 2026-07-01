import 'package:shared_preferences/shared_preferences.dart';

/// Minimal persisted preferences. Currently only the Dailymotion access token
/// needs persisting (the auth session lives in SecureStorageService). Call
/// [initPreferences] once at startup before any getter/setter is used.
class UserPreferences {
  static final UserPreferences _instance = UserPreferences._internal();

  factory UserPreferences() => _instance;

  UserPreferences._internal();

  late SharedPreferences _prefs;

  Future<void> initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get dailyToken => _prefs.getString('daily_token') ?? '';

  set dailyToken(String token) {
    _prefs.setString('daily_token', token);
  }
}

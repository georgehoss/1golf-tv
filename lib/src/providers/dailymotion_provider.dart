import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/shared_preferences.dart';

/// Resolves a Dailymotion `livestreamID` into a playable HLS URL. Ported
/// verbatim from `one_golf_app` — the credentials, endpoints and 401-retry
/// behaviour must stay identical for playback to keep working.
class DailyMotionProvider {
  Future<Map<String, dynamic>> obtainDailyToken() async {
    try {
      final response = await http.post(
        Uri.parse('https://partner.api.dailymotion.com/oauth/v1/token'),
        body: {
          'grant_type': 'client_credentials',
          'client_id': '40aa4bdb395fa3515795',
          'client_secret': "wr'*cku&p4ehqP<SRvm'#Fn:/Gl@[qL8",
          'scope': 'manage_videos',
        },
      );
      final decodedData = json.decode(response.body);

      if (decodedData is Map<String, dynamic> && decodedData.isNotEmpty) {
        final token = decodedData['access_token'];
        if (token is String) UserPreferences().dailyToken = token;
      }
      return decodedData is Map<String, dynamic> ? decodedData : {};
    } on Exception catch (e) {
      debugPrint(e.toString());
      return <String, dynamic>{};
    }
  }

  /// Returns the raw Dailymotion response; the playable URL is under
  /// `stream_live_hls_url`. Refreshes the token once on a 401 and retries.
  Future<Map<String, dynamic>> getUrlVideo(String videoId) async {
    Map<String, dynamic> result = await _attemptGetUrl(videoId);

    final isInvalidToken =
        result['error'] != null && result['error']['code'] == 401;

    if (isInvalidToken) {
      debugPrint('Token inválido, obteniendo nuevo token...');
      await obtainDailyToken();
      result = await _attemptGetUrl(videoId);
    }

    return result;
  }

  Future<Map<String, dynamic>> _attemptGetUrl(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://partner.api.dailymotion.com/rest/video/$videoId'
          '?fields=stream_live_hls_url&no_expire=1&no_ip_lock=0',
        ),
        headers: {
          'Authorization': 'Bearer ${UserPreferences().dailyToken}',
        },
      );

      final decodedData = json.decode(response.body);
      return decodedData is Map<String, dynamic> ? decodedData : {};
    } catch (e) {
      debugPrint('Error obteniendo URL del video: ${e.toString()}');
      return <String, dynamic>{};
    }
  }
}

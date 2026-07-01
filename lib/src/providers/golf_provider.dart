import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_response.dart';
import '../models/league_details.dart';
import '../models/show_details.dart';
import '../utils/app_constants.dart';

class GolfProvider {
  final String _baseUrl = AppConstants.apiBaseUrl;

  final Map<String, String> _headers = {
    'Content-Type': 'application/x-www-form-urlencoded',
    HttpHeaders.authorizationHeader: 'Bearer ${AppConstants.apiToken}',
  };

  Future<AppResponseList> getHome() async {
    try {
      final response = await http.get(
        Uri.parse('https://$_baseUrl/app'),
        headers: _headers,
      );
      final decodedData = json.decode(response.body);
      return AppResponseList.fromJson(decodedData);
    } on Exception catch (e) {
      if (kDebugMode) print('GolfProvider.getHome error: $e');
      return AppResponseList(list: []);
    }
  }

  Future<LeagueDetails?> getLeagueDetails(int leagueId) async {
    try {
      final response = await http.get(
        Uri.parse('https://$_baseUrl/league/$leagueId'),
        headers: _headers,
      );
      final list = leagueDetailsFromJson(response.body);
      return list.isNotEmpty ? list[0] : null;
    } on Exception catch (e) {
      if (kDebugMode) print('GolfProvider.getLeagueDetails error: $e');
      return null;
    }
  }

  Future<ShowDetails?> getShowDetails(int showId) async {
    try {
      final response = await http.get(
        Uri.parse('https://$_baseUrl/show/$showId'),
        headers: _headers,
      );
      final list = showDetailsFromJson(response.body);
      return list.isNotEmpty ? list[0] : null;
    } on Exception catch (e) {
      if (kDebugMode) print('GolfProvider.getShowDetails error: $e');
      return null;
    }
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/udhari.dart';

class UdhariStorageService {
  static const String _udhariKey = 'udharis';

  Future<List<Udhari>> loadUdharis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? udhariJson = prefs.getString(_udhariKey);
      
      if (udhariJson == null) {
        return [];
      }

      final List<dynamic> decoded = json.decode(udhariJson);
      return decoded.map((item) => Udhari.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveUdharis(List<Udhari> udharis) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(
        udharis.map((udhari) => udhari.toJson()).toList(),
      );
      await prefs.setString(_udhariKey, encoded);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_udhariKey);
  }
}

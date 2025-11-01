import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _phoneKey = 'user_phone';

  /// Register a new user with phone number and password
  static Future<Map<String, dynamic>> register({
    required String phoneNumber,
    required String password,
    required String name,
    String? email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': phoneNumber,
          'password': password,
          'name': name,
          'email': email,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        // Registration successful
        await _storage.write(key: _tokenKey, value: data['token']);
        await _storage.write(key: _userKey, value: json.encode(data['user']));
        await _storage.write(key: _phoneKey, value: phoneNumber);

        return {
          'success': true,
          'message': 'Registration successful',
          'user': data['user'],
          'token': data['token'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Login with phone number and password
  static Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phoneNumber, 'password': password}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Login successful
        await _storage.write(key: _tokenKey, value: data['token']);
        await _storage.write(key: _userKey, value: json.encode(data['user']));
        await _storage.write(key: _phoneKey, value: phoneNumber);

        return {
          'success': true,
          'message': 'Login successful',
          'user': data['user'],
          'token': data['token'],
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Get current user data
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null) {
      return json.decode(userJson);
    }
    return null;
  }

  /// Get current user's phone number
  static Future<String?> getCurrentUserPhone() async {
    return await _storage.read(key: _phoneKey);
  }

  /// Get authentication token
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Logout user
  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _phoneKey);
  }

  /// Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? email,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'name': name, 'email': email}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Update successful
        await _storage.write(key: _userKey, value: json.encode(data['user']));

        return {
          'success': true,
          'message': 'Profile updated successfully',
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Update failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Change password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final data = json.decode(response.body);

      return {
        'success': response.statusCode == 200,
        'message':
            data['message'] ??
            (response.statusCode == 200
                ? 'Password changed successfully'
                : 'Password change failed'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Verify phone number (for future OTP implementation)
  static Future<Map<String, dynamic>> verifyPhoneNumber(
    String phoneNumber,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-phone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phoneNumber}),
      );

      final data = json.decode(response.body);

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Verification request sent',
        'exists': data['exists'] ?? false,
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get authenticated headers for API requests
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Check various valid formats
    return cleaned.length >= 10 &&
        (cleaned.startsWith('+91') ||
            cleaned.startsWith('91') ||
            cleaned.length == 10);
  }

  /// Format phone number for storage
  static String formatPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Handle different formats
    if (cleaned.startsWith('0')) {
      // Remove leading 0 and add country code
      cleaned = '+91${cleaned.substring(1)}';
    } else if (cleaned.startsWith('91') && cleaned.length == 12) {
      // Add + to country code
      cleaned = '+$cleaned';
    } else if (cleaned.startsWith('+91') && cleaned.length == 13) {
      // Already in correct format
      return cleaned;
    } else if (cleaned.length == 10) {
      // Add country code
      cleaned = '+91$cleaned';
    }

    return cleaned;
  }
}

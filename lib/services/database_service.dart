import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/expense.dart';
import '../models/udhari.dart';
import '../models/group_expense.dart';

class DatabaseService {
  // For local development - update these when you deploy
  static const String _baseUrl = 'http://localhost:8080/api';
  static const String _wsUrl = 'ws://localhost:8080';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  static String? _userId;
  static String? _authToken;
  static WebSocketChannel? _wsChannel;
  static Function(Map<String, dynamic>)? _onDataUpdate;

  // Initialize user session
  static Future<bool> initializeUser() async {
    _userId = await _storage.read(key: 'user_id');
    _authToken = await _storage.read(key: 'auth_token');
    
    if (_userId == null) {
      // Generate new user ID if first time
      _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      await _storage.write(key: 'user_id', value: _userId);
    }
    
    if (_authToken == null) {
      // Generate auth token
      _authToken = 'token_${DateTime.now().millisecondsSinceEpoch}';
      await _storage.write(key: 'auth_token', value: _authToken);
    }
    
    return true;
  }

  // Connect to WebSocket for real-time updates
  static Future<void> connectWebSocket({
    required Function(Map<String, dynamic>) onDataUpdate,
  }) async {
    if (_userId == null) await initializeUser();
    
    try {
      _onDataUpdate = onDataUpdate;
      _wsChannel = WebSocketChannel.connect(
        Uri.parse(_wsUrl),
      );
      
      _wsChannel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> update = json.decode(data);
            _onDataUpdate?.call(update);
          } catch (e) {
            print('Error parsing WebSocket data: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          // Attempt to reconnect after 5 seconds
          Future.delayed(Duration(seconds: 5), () {
            connectWebSocket(onDataUpdate: onDataUpdate);
          });
        },
        onDone: () {
          print('WebSocket connection closed');
          // Attempt to reconnect after 3 seconds
          Future.delayed(Duration(seconds: 3), () {
            connectWebSocket(onDataUpdate: onDataUpdate);
          });
        },
      );
    } catch (e) {
      print('Failed to connect WebSocket: $e');
    }
  }

  // Disconnect WebSocket
  static void disconnectWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  // Send HTTP request with authentication
  static Future<http.Response> _sendRequest(
    String method,
    String endpoint,
    Map<String, dynamic>? data,
  ) async {
    if (_userId == null || _authToken == null) {
      await initializeUser();
    }

    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_authToken',
      'User-ID': _userId!,
    };

    http.Response response;
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: data != null ? json.encode(data) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: headers,
          body: data != null ? json.encode(data) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    if (response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    return response;
  }

  // =============== FRIEND OPERATIONS ===============

  // Add friend and notify all connected users
  static Future<void> addFriend(Friend friend) async {
    try {
      await _sendRequest('POST', '/friends', {
        'id': friend.id,
        'name': friend.name,
        'email': friend.email,
        'phoneNumber': friend.phoneNumber,
        'addedBy': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Broadcast to friends via WebSocket
      _broadcastUpdate({
        'type': 'friend_added',
        'data': friend.toJson(),
        'userId': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to add friend: $e');
    }
  }

  // Update friend
  static Future<void> updateFriend(Friend friend) async {
    try {
      await _sendRequest('PUT', '/friends/${friend.id}', {
        'name': friend.name,
        'email': friend.email,
        'phoneNumber': friend.phoneNumber,
        'updatedBy': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _broadcastUpdate({
        'type': 'friend_updated',
        'data': friend.toJson(),
        'userId': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update friend: $e');
    }
  }

  // Delete friend
  static Future<void> deleteFriend(String friendId) async {
    try {
      await _sendRequest('DELETE', '/friends/$friendId', null);

      _broadcastUpdate({
        'type': 'friend_deleted',
        'data': {'id': friendId},
        'userId': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to delete friend: $e');
    }
  }

  // Get all friends
  static Future<List<Friend>> getFriends() async {
    try {
      final response = await _sendRequest('GET', '/friends', null);
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Friend.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get friends: $e');
    }
  }

  // =============== GROUP EXPENSE OPERATIONS ===============

  // Add group expense
  static Future<void> addGroupExpense(GroupExpense expense) async {
    try {
      await _sendRequest('POST', '/group-expenses', {
        'id': expense.id,
        'title': expense.title,
        'totalAmount': expense.totalAmount,
        'date': expense.date.toIso8601String(),
        'category': expense.category.index,
        'paidBy': expense.paidBy,
        'participants': expense.participants,
        'splits': expense.splits,
        'note': expense.note,
        'createdBy': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _broadcastUpdate({
        'type': 'group_expense_added',
        'data': expense.toJson(),
        'userId': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to add group expense: $e');
    }
  }

  // Update group expense
  static Future<void> updateGroupExpense(GroupExpense expense) async {
    try {
      await _sendRequest('PUT', '/group-expenses/${expense.id}', {
        'title': expense.title,
        'totalAmount': expense.totalAmount,
        'date': expense.date.toIso8601String(),
        'category': expense.category.index,
        'paidBy': expense.paidBy,
        'participants': expense.participants,
        'splits': expense.splits,
        'note': expense.note,
        'updatedBy': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _broadcastUpdate({
        'type': 'group_expense_updated',
        'data': expense.toJson(),
        'userId': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update group expense: $e');
    }
  }

  // Delete group expense
  static Future<void> deleteGroupExpense(String expenseId) async {
    try {
      await _sendRequest('DELETE', '/group-expenses/$expenseId', null);

      _broadcastUpdate({
        'type': 'group_expense_deleted',
        'data': {'id': expenseId},
        'userId': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to delete group expense: $e');
    }
  }

  // Get all group expenses
  static Future<List<GroupExpense>> getGroupExpenses() async {
    try {
      final response = await _sendRequest('GET', '/group-expenses', null);
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => GroupExpense.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get group expenses: $e');
    }
  }

  // =============== PERSONAL EXPENSE OPERATIONS ===============

  // Add personal expense
  static Future<void> addExpense(Expense expense) async {
    try {
      await _sendRequest('POST', '/expenses', {
        'id': expense.id,
        'title': expense.title,
        'amount': expense.amount,
        'date': expense.date.toIso8601String(),
        'category': expense.category.index,
        'note': expense.note,
        'createdBy': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to add expense: $e');
    }
  }

  // Get personal expenses
  static Future<List<Expense>> getExpenses() async {
    try {
      final response = await _sendRequest('GET', '/expenses', null);
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Expense.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get expenses: $e');
    }
  }

  // =============== UDHARI OPERATIONS ===============

  // Add udhari
  static Future<void> addUdhari(Udhari udhari) async {
    try {
      await _sendRequest('POST', '/udhari', {
        'id': udhari.id,
        'personName': udhari.personName,
        'amount': udhari.amount,
        'amountPaid': udhari.amountPaid,
        'type': udhari.type.index,
        'status': udhari.status.index,
        'date': udhari.date.toIso8601String(),
        'dueDate': udhari.dueDate?.toIso8601String(),
        'note': udhari.note,
        'phoneNumber': udhari.phoneNumber,
        'createdBy': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to add udhari: $e');
    }
  }

  // Get udhari records
  static Future<List<Udhari>> getUdhariRecords() async {
    try {
      final response = await _sendRequest('GET', '/udhari', null);
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Udhari.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get udhari records: $e');
    }
  }

  // =============== USER MANAGEMENT ===============

  // Invite friend to app (send them a link to download and connect)
  static Future<String> inviteFriend(String friendName, String? friendPhone, String? friendEmail) async {
    try {
      final response = await _sendRequest('POST', '/invite', {
        'friendName': friendName,
        'friendPhone': friendPhone,
        'friendEmail': friendEmail,
        'invitedBy': _userId,
        'inviteCode': 'inv_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
      });

      final data = json.decode(response.body);
      return data['inviteLink'] ?? 'expense://invite/${data['inviteCode']}';
    } catch (e) {
      throw Exception('Failed to create invite: $e');
    }
  }

  // Accept invite and connect with existing user
  static Future<void> acceptInvite(String inviteCode) async {
    try {
      await _sendRequest('POST', '/accept-invite', {
        'inviteCode': inviteCode,
        'acceptedBy': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to accept invite: $e');
    }
  }

  // Get user's current balance with all friends
  static Future<Map<String, double>> getBalances() async {
    try {
      final response = await _sendRequest('GET', '/balances', null);
      final Map<String, dynamic> data = json.decode(response.body);
      return data.map((key, value) => MapEntry(key, value.toDouble()));
    } catch (e) {
      throw Exception('Failed to get balances: $e');
    }
  }

  // =============== PRIVATE METHODS ===============

  // Broadcast update to WebSocket
  static void _broadcastUpdate(Map<String, dynamic> update) {
    if (_wsChannel != null) {
      try {
        _wsChannel!.sink.add(json.encode(update));
      } catch (e) {
        print('Failed to broadcast update: $e');
      }
    }
  }

  // Get current user ID
  static String? get currentUserId => _userId;

  // Check if connected to internet
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Sync offline data when connection is restored
  static Future<void> syncOfflineData() async {
    // This would handle syncing any data that was stored locally
    // while the device was offline
    // Implementation depends on your offline storage strategy
  }

  // =============== CONTACT INTEGRATION METHODS ===============

  /// Check if a user exists with the given phone number
  static Future<bool> checkUserExists(String phoneNumber) async {
    try {
      final response = await _sendRequest('POST', '/users/check', {
        'phone': phoneNumber,
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }

  /// Get user information by phone number
  static Future<Map<String, dynamic>?> getUserByPhone(String phoneNumber) async {
    try {
      final response = await _sendRequest('POST', '/users/by-phone', {
        'phone': phoneNumber,
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['user'];
      }
      return null;
    } catch (e) {
      print('Error getting user by phone: $e');
      return null;
    }
  }

  /// Register a new user with contact information
  static Future<Map<String, dynamic>?> registerUser({
    required String name,
    required String phone,
    String? email,
  }) async {
    try {
      final response = await _sendRequest('POST', '/users/register', {
        'name': name,
        'phone': phone,
        'email': email,
      });
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['user'];
      }
      return null;
    } catch (e) {
      print('Error registering user: $e');
      return null;
    }
  }

  /// Search users by name or phone (for finding friends)
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _sendRequest('POST', '/users/search', {
        'query': query,
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['users'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }
}
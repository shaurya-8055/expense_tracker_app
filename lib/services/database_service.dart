import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/expense.dart';
import '../models/udhari.dart';
import '../models/group_expense.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class DatabaseService {
  static WebSocketChannel? _wsChannel;
  static Function(Map<String, dynamic>)? _onDataUpdate;

  // Initialize user session with authentication
  static Future<bool> initializeUser() async {
    return await AuthService.isLoggedIn();
  }

  // Get authenticated user ID
  static Future<String?> _getCurrentUserId() async {
    final user = await AuthService.getCurrentUser();
    return user?['id']?.toString();
  }

  // Get authentication token
  static Future<String?> _getAuthToken() async {
    return await AuthService.getToken();
  }

  // Connect to WebSocket for real-time updates
  static Future<void> connectWebSocket({
    required Function(Map<String, dynamic>) onDataUpdate,
  }) async {
    if (!await initializeUser()) return;

    try {
      _onDataUpdate = onDataUpdate;
      _wsChannel = WebSocketChannel.connect(Uri.parse(ServerConfig.wsUrl));

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
    if (!await initializeUser()) {
      throw Exception('User not authenticated');
    }

    final token = await _getAuthToken();
    final userId = await _getCurrentUserId();

    if (token == null || userId == null) {
      throw Exception('Authentication token or user ID not found');
    }

    final uri = Uri.parse('${ServerConfig.baseUrl}$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'User-ID': userId,
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
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      await _sendRequest('POST', '/api/friends', {
        'id': friend.id,
        'name': friend.name,
        'email': friend.email,
        'phoneNumber': friend.phoneNumber,
        'addedBy': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Broadcast to friends via WebSocket
      _broadcastUpdate({
        'type': 'friend_added',
        'data': friend.toJson(),
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to add friend: $e');
    }
  }

  // Update friend
  static Future<void> updateFriend(Friend friend) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      await _sendRequest('PUT', '/api/friends/${friend.id}', {
        'name': friend.name,
        'email': friend.email,
        'phoneNumber': friend.phoneNumber,
        'updatedBy': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _broadcastUpdate({
        'type': 'friend_updated',
        'data': friend.toJson(),
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update friend: $e');
    }
  }

  // Delete friend
  static Future<void> deleteFriend(String friendId) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      await _sendRequest('DELETE', '/api/friends/$friendId', null);

      _broadcastUpdate({
        'type': 'friend_deleted',
        'data': {'id': friendId},
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to delete friend: $e');
    }
  }

  // Get all friends
  static Future<List<Friend>> getFriends() async {
    try {
      final response = await _sendRequest('GET', '/api/friends', null);
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
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      await _sendRequest('POST', '/api/group-expenses', {
        'id': expense.id,
        'title': expense.title,
        'totalAmount': expense.totalAmount,
        'date': expense.date.toIso8601String(),
        'category': expense.category.index,
        'paidBy': expense.paidBy,
        'participants': expense.participants,
        'splits': expense.splits,
        'note': expense.note,
        'createdBy': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _broadcastUpdate({
        'type': 'group_expense_added',
        'data': expense.toJson(),
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to add group expense: $e');
    }
  }

  // Update group expense
  static Future<void> updateGroupExpense(GroupExpense expense) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      await _sendRequest('PUT', '/api/group-expenses/${expense.id}', {
        'title': expense.title,
        'totalAmount': expense.totalAmount,
        'date': expense.date.toIso8601String(),
        'category': expense.category.index,
        'paidBy': expense.paidBy,
        'participants': expense.participants,
        'splits': expense.splits,
        'note': expense.note,
        'updatedBy': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _broadcastUpdate({
        'type': 'group_expense_updated',
        'data': expense.toJson(),
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update group expense: $e');
    }
  }

  // Delete group expense
  static Future<void> deleteGroupExpense(String expenseId) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      await _sendRequest('DELETE', '/api/group-expenses/$expenseId', null);

      _broadcastUpdate({
        'type': 'group_expense_deleted',
        'data': {'id': expenseId},
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to delete group expense: $e');
    }
  }

  // Get all group expenses
  static Future<List<GroupExpense>> getGroupExpenses() async {
    try {
      final response = await _sendRequest('GET', '/api/group-expenses', null);
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
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      await _sendRequest('POST', '/api/personal-expenses', {
        'id': expense.id,
        'title': expense.title,
        'amount': expense.amount,
        'date': expense.date.toIso8601String(),
        'category': expense.category.index,
        'note': expense.note,
        'createdBy': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to add expense: $e');
    }
  }

  // Update personal expense
  static Future<void> updateExpense(Expense expense) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      await _sendRequest('PUT', '/api/personal-expenses/${expense.id}', {
        'title': expense.title,
        'amount': expense.amount,
        'date': expense.date.toIso8601String(),
        'category': expense.category.index,
        'note': expense.note,
        'updatedBy': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update expense: $e');
    }
  }

  // Delete personal expense
  static Future<void> deleteExpense(String expenseId) async {
    try {
      await _sendRequest('DELETE', '/api/personal-expenses/$expenseId', null);
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }

  // Get personal expenses
  static Future<List<Expense>> getExpenses() async {
    try {
      final response = await _sendRequest(
        'GET',
        '/api/personal-expenses',
        null,
      );
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
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      await _sendRequest('POST', '/api/udhari', {
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
        'createdBy': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to add udhari: $e');
    }
  }

  // Update udhari
  static Future<void> updateUdhari(Udhari udhari) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      await _sendRequest('PUT', '/api/udhari/${udhari.id}', {
        'personName': udhari.personName,
        'amount': udhari.amount,
        'amountPaid': udhari.amountPaid,
        'type': udhari.type.index,
        'status': udhari.status.index,
        'date': udhari.date.toIso8601String(),
        'dueDate': udhari.dueDate?.toIso8601String(),
        'note': udhari.note,
        'phoneNumber': udhari.phoneNumber,
        'updatedBy': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update udhari: $e');
    }
  }

  // Delete udhari
  static Future<void> deleteUdhari(String udhariId) async {
    try {
      await _sendRequest('DELETE', '/api/udhari/$udhariId', null);
    } catch (e) {
      throw Exception('Failed to delete udhari: $e');
    }
  }

  // Get udhari records
  static Future<List<Udhari>> getUdhariRecords() async {
    try {
      final response = await _sendRequest('GET', '/api/udhari', null);
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Udhari.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get udhari records: $e');
    }
  }

  // =============== USER MANAGEMENT ===============

  // Add friend by phone number (creates pending invitation)
  static Future<void> addFriendByPhone(
    String friendPhone,
    String friendName,
  ) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      await _sendRequest('POST', '/api/friends/invite', {
        'friendPhone': friendPhone,
        'friendName': friendName,
        'invitedBy': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to add friend by phone: $e');
    }
  }

  // Get pending invitations for current user
  static Future<List<Map<String, dynamic>>> getPendingInvitations() async {
    try {
      final response = await _sendRequest('GET', '/api/friends/pending', null);
      final List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Failed to get pending invitations: $e');
    }
  }

  // Accept friend invitation
  static Future<void> acceptFriendInvitation(String invitationId) async {
    try {
      await _sendRequest('POST', '/api/friends/accept', {
        'invitationId': invitationId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to accept friend invitation: $e');
    }
  }

  // Get shared expenses with friends
  static Future<List<Map<String, dynamic>>> getSharedExpenses() async {
    try {
      final response = await _sendRequest('GET', '/api/expenses/shared', null);
      final List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Failed to get shared expenses: $e');
    }
  }

  // Invite friend to app (send them a link to download and connect)
  static Future<String> inviteFriend(
    String friendName,
    String? friendPhone,
    String? friendEmail,
  ) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      final response = await _sendRequest('POST', '/api/invite', {
        'friendName': friendName,
        'friendPhone': friendPhone,
        'friendEmail': friendEmail,
        'invitedBy': userId,
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
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      await _sendRequest('POST', '/api/accept-invite', {
        'inviteCode': inviteCode,
        'acceptedBy': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to accept invite: $e');
    }
  }

  // Get user's current balance with all friends
  static Future<Map<String, double>> getBalances() async {
    try {
      final response = await _sendRequest('GET', '/api/balances', null);
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
  static Future<String?> getCurrentUserId() async {
    return await _getCurrentUserId();
  }

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
      final response = await _sendRequest('POST', '/api/users/check', {
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
  static Future<Map<String, dynamic>?> getUserByPhone(
    String phoneNumber,
  ) async {
    try {
      final response = await _sendRequest('POST', '/api/users/by-phone', {
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
      final response = await _sendRequest('POST', '/api/users/register', {
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
      final response = await _sendRequest('POST', '/api/users/search', {
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

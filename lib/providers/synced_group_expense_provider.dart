import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/group_expense.dart';
import '../services/database_service.dart';
import '../services/group_expense_storage_service.dart';

class SyncedGroupExpenseProvider with ChangeNotifier {
  List<Friend> _friends = [];
  List<GroupExpense> _groupExpenses = [];
  final GroupExpenseStorageService _localStorageService = GroupExpenseStorageService();
  bool _isLoading = false;
  bool _isOnline = false;
  final String _currentUserId = 'me';

  List<Friend> get friends => _friends;
  List<GroupExpense> get groupExpenses => _groupExpenses;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;
  String get currentUserId => _currentUserId;

  // Initialize the provider
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize database service
      await DatabaseService.initializeUser();
      
      // Check internet connectivity
      final connectivityResults = await Connectivity().checkConnectivity();
      _isOnline = connectivityResults.isNotEmpty && !connectivityResults.every((result) => result == ConnectivityResult.none);

      if (_isOnline) {
        // Connect to real-time updates
        await DatabaseService.connectWebSocket(
          onDataUpdate: _handleRealTimeUpdate,
        );
        
        // Load data from server
        await _loadFromServer();
      } else {
        // Load from local storage when offline
        await _loadFromLocal();
      }

      // Listen for connectivity changes
      Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
      
    } catch (e) {
      print('Error initializing SyncedGroupExpenseProvider: $e');
      // Fallback to local storage
      await _loadFromLocal();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && !results.every((result) => result == ConnectivityResult.none);
    
    if (!wasOnline && _isOnline) {
      // Just came online - sync data
      await _syncWithServer();
      // Connect WebSocket
      await DatabaseService.connectWebSocket(
        onDataUpdate: _handleRealTimeUpdate,
      );
    } else if (wasOnline && !_isOnline) {
      // Just went offline - disconnect WebSocket
      DatabaseService.disconnectWebSocket();
    }
    
    notifyListeners();
  }

  // Handle real-time updates from WebSocket
  void _handleRealTimeUpdate(Map<String, dynamic> update) {
    final type = update['type'];
    final data = update['data'];
    final userId = update['userId'];
    
    // Don't process updates from self
    if (userId == DatabaseService.currentUserId) return;

    switch (type) {
      case 'friend_added':
        final friend = Friend.fromJson(data);
        if (!_friends.any((f) => f.id == friend.id)) {
          _friends.add(friend);
          _saveToLocal();
          notifyListeners();
        }
        break;
        
      case 'friend_updated':
        final friend = Friend.fromJson(data);
        final index = _friends.indexWhere((f) => f.id == friend.id);
        if (index != -1) {
          _friends[index] = friend;
          _saveToLocal();
          notifyListeners();
        }
        break;
        
      case 'friend_deleted':
        final friendId = data['id'];
        _friends.removeWhere((f) => f.id == friendId);
        _saveToLocal();
        notifyListeners();
        break;
        
      case 'group_expense_added':
        final expense = GroupExpense.fromJson(data);
        if (!_groupExpenses.any((e) => e.id == expense.id)) {
          _groupExpenses.add(expense);
          _saveToLocal();
          notifyListeners();
        }
        break;
        
      case 'group_expense_updated':
        final expense = GroupExpense.fromJson(data);
        final index = _groupExpenses.indexWhere((e) => e.id == expense.id);
        if (index != -1) {
          _groupExpenses[index] = expense;
          _saveToLocal();
          notifyListeners();
        }
        break;
        
      case 'group_expense_deleted':
        final expenseId = data['id'];
        _groupExpenses.removeWhere((e) => e.id == expenseId);
        _saveToLocal();
        notifyListeners();
        break;
    }
  }

  // Load data from server
  Future<void> _loadFromServer() async {
    try {
      final friendsFromServer = await DatabaseService.getFriends();
      final expensesFromServer = await DatabaseService.getGroupExpenses();
      
      _friends = friendsFromServer;
      _groupExpenses = expensesFromServer;
      
      // Save to local storage for offline access
      await _saveToLocal();
    } catch (e) {
      print('Error loading from server: $e');
      // Fallback to local storage
      await _loadFromLocal();
    }
  }

  // Load data from local storage
  Future<void> _loadFromLocal() async {
    _friends = await _localStorageService.loadFriends();
    _groupExpenses = await _localStorageService.loadGroupExpenses();
  }

  // Save data to local storage
  Future<void> _saveToLocal() async {
    await _localStorageService.saveFriends(_friends);
    await _localStorageService.saveGroupExpenses(_groupExpenses);
  }

  // Sync with server when coming back online
  Future<void> _syncWithServer() async {
    if (!_isOnline) return;
    
    try {
      // This is a simplified sync - in a real app you'd need conflict resolution
      await _loadFromServer();
    } catch (e) {
      print('Error syncing with server: $e');
    }
  }

  // =============== FRIEND MANAGEMENT ===============

  Future<void> addFriend(Friend friend) async {
    // Add locally first for immediate UI update
    _friends.add(friend);
    await _saveToLocal();
    notifyListeners();
    
    // Sync to server if online
    if (_isOnline) {
      try {
        await DatabaseService.addFriend(friend);
      } catch (e) {
        print('Error syncing friend to server: $e');
        // In a real app, you'd queue this for retry when back online
      }
    }
  }

  Future<void> updateFriend(String id, Friend updatedFriend) async {
    final index = _friends.indexWhere((f) => f.id == id);
    if (index != -1) {
      _friends[index] = updatedFriend;
      await _saveToLocal();
      notifyListeners();
      
      // Sync to server if online
      if (_isOnline) {
        try {
          await DatabaseService.updateFriend(updatedFriend);
        } catch (e) {
          print('Error syncing friend update to server: $e');
        }
      }
    }
  }

  Future<void> deleteFriend(String id) async {
    _friends.removeWhere((f) => f.id == id);
    await _saveToLocal();
    notifyListeners();
    
    // Sync to server if online
    if (_isOnline) {
      try {
        await DatabaseService.deleteFriend(id);
      } catch (e) {
        print('Error syncing friend deletion to server: $e');
      }
    }
  }

  Friend? getFriendById(String id) {
    try {
      return _friends.firstWhere((f) => f.id == id);
    } catch (e) {
      return null;
    }
  }

  // =============== GROUP EXPENSE MANAGEMENT ===============

  Future<void> addGroupExpense(GroupExpense expense) async {
    _groupExpenses.add(expense);
    await _saveToLocal();
    notifyListeners();
    
    // Sync to server if online
    if (_isOnline) {
      try {
        await DatabaseService.addGroupExpense(expense);
      } catch (e) {
        print('Error syncing group expense to server: $e');
      }
    }
  }

  Future<void> updateGroupExpense(String id, GroupExpense updatedExpense) async {
    final index = _groupExpenses.indexWhere((e) => e.id == id);
    if (index != -1) {
      _groupExpenses[index] = updatedExpense;
      await _saveToLocal();
      notifyListeners();
      
      // Sync to server if online
      if (_isOnline) {
        try {
          await DatabaseService.updateGroupExpense(updatedExpense);
        } catch (e) {
          print('Error syncing group expense update to server: $e');
        }
      }
    }
  }

  Future<void> deleteGroupExpense(String id) async {
    _groupExpenses.removeWhere((e) => e.id == id);
    await _saveToLocal();
    notifyListeners();
    
    // Sync to server if online
    if (_isOnline) {
      try {
        await DatabaseService.deleteGroupExpense(id);
      } catch (e) {
        print('Error syncing group expense deletion to server: $e');
      }
    }
  }

  // =============== BALANCE CALCULATIONS ===============

  Map<String, double> getBalances() {
    final Map<String, double> balances = {};

    // Initialize balances for current user and all friends
    balances[_currentUserId] = 0;
    for (var friend in _friends) {
      balances[friend.id] = 0;
    }

    for (var expense in _groupExpenses) {
      for (var entry in expense.splits.entries) {
        final friendId = entry.key;
        final amount = entry.value;

        if (friendId == expense.paidBy) {
          continue; // Skip if they paid for themselves
        }

        if (expense.paidBy == _currentUserId) {
          // Current user paid, others owe
          balances[friendId] = (balances[friendId] ?? 0) - amount;
        } else if (friendId == _currentUserId) {
          // Current user owes to whoever paid
          balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + amount;
        }
      }
    }

    return balances;
  }

  List<Settlement> getSettlementSuggestions() {
    final balances = getBalances();
    final List<Settlement> settlements = [];

    final creditors = <String, double>{};
    final debtors = <String, double>{};

    balances.forEach((friendId, balance) {
      if (balance > 0.01) {
        creditors[friendId] = balance;
      } else if (balance < -0.01) {
        debtors[friendId] = -balance;
      }
    });

    // Greedy algorithm to minimize transactions
    while (creditors.isNotEmpty && debtors.isNotEmpty) {
      final maxCreditor = creditors.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      final maxDebtor = debtors.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );

      final amount = maxCreditor.value < maxDebtor.value
          ? maxCreditor.value
          : maxDebtor.value;

      settlements.add(
        Settlement(
          fromFriendId: maxDebtor.key,
          toFriendId: maxCreditor.key,
          amount: amount,
        ),
      );

      creditors[maxCreditor.key] = maxCreditor.value - amount;
      debtors[maxDebtor.key] = maxDebtor.value - amount;

      if (creditors[maxCreditor.key]! < 0.01) {
        creditors.remove(maxCreditor.key);
      }
      if (debtors[maxDebtor.key]! < 0.01) {
        debtors.remove(maxDebtor.key);
      }
    }

    return settlements;
  }

  double getTotalOwed() {
    final balances = getBalances();
    return balances.values.where((v) => v > 0).fold(0, (sum, v) => sum + v);
  }

  double getTotalOwing() {
    final balances = getBalances();
    return balances.values.where((v) => v < 0).fold(0, (sum, v) => sum - v);
  }

  List<GroupExpense> getExpensesWithFriend(String friendId) {
    return _groupExpenses
        .where((e) => e.participants.contains(friendId) || e.paidBy == friendId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // =============== INVITE SYSTEM ===============

  Future<String> inviteFriend(String friendName, String? friendPhone, String? friendEmail) async {
    if (_isOnline) {
      try {
        return await DatabaseService.inviteFriend(friendName, friendPhone, friendEmail);
      } catch (e) {
        print('Error creating invite: $e');
        // Generate a local invite link as fallback
        return 'expense://invite/local_${DateTime.now().millisecondsSinceEpoch}';
      }
    } else {
      // Generate a local invite link when offline
      return 'expense://invite/local_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> acceptInvite(String inviteCode) async {
    if (_isOnline) {
      try {
        await DatabaseService.acceptInvite(inviteCode);
        // Refresh data after accepting invite
        await _loadFromServer();
        notifyListeners();
      } catch (e) {
        print('Error accepting invite: $e');
      }
    }
  }

  @override
  void dispose() {
    DatabaseService.disconnectWebSocket();
    super.dispose();
  }
}
import 'package:flutter/foundation.dart';
import '../models/group_expense.dart';
import '../services/group_expense_storage_service.dart';

class GroupExpenseProvider with ChangeNotifier {
  List<Friend> _friends = [];
  List<GroupExpense> _groupExpenses = [];
  final GroupExpenseStorageService _storageService =
      GroupExpenseStorageService();
  bool _isLoading = false;
  final String _currentUserId = 'me'; // Current user ID

  List<Friend> get friends => _friends;
  List<GroupExpense> get groupExpenses => _groupExpenses;
  bool get isLoading => _isLoading;
  String get currentUserId => _currentUserId;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    _friends = await _storageService.loadFriends();
    _groupExpenses = await _storageService.loadGroupExpenses();

    _isLoading = false;
    notifyListeners();
  }

  // Friend Management
  Future<void> addFriend(Friend friend) async {
    _friends.add(friend);
    await _storageService.saveFriends(_friends);
    notifyListeners();
  }

  Future<void> updateFriend(String id, Friend updatedFriend) async {
    final index = _friends.indexWhere((f) => f.id == id);
    if (index != -1) {
      _friends[index] = updatedFriend;
      await _storageService.saveFriends(_friends);
      notifyListeners();
    }
  }

  Future<void> deleteFriend(String id) async {
    _friends.removeWhere((f) => f.id == id);
    await _storageService.saveFriends(_friends);
    notifyListeners();
  }

  Friend? getFriendById(String id) {
    try {
      return _friends.firstWhere((f) => f.id == id);
    } catch (e) {
      return null;
    }
  }

  // Group Expense Management
  Future<void> addGroupExpense(GroupExpense expense) async {
    _groupExpenses.add(expense);
    await _storageService.saveGroupExpenses(_groupExpenses);
    notifyListeners();
  }

  Future<void> updateGroupExpense(
    String id,
    GroupExpense updatedExpense,
  ) async {
    final index = _groupExpenses.indexWhere((e) => e.id == id);
    if (index != -1) {
      _groupExpenses[index] = updatedExpense;
      await _storageService.saveGroupExpenses(_groupExpenses);
      notifyListeners();
    }
  }

  Future<void> deleteGroupExpense(String id) async {
    _groupExpenses.removeWhere((e) => e.id == id);
    await _storageService.saveGroupExpenses(_groupExpenses);
    notifyListeners();
  }

  // Calculate balances
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

  // Calculate settlement suggestions
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
}

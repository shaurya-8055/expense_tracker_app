import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_expense.dart';

class GroupExpenseStorageService {
  static const String _friendsKey = 'friends';
  static const String _groupExpensesKey = 'group_expenses';

  Future<List<Friend>> loadFriends() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? friendsJson = prefs.getString(_friendsKey);

      if (friendsJson == null) {
        return [];
      }

      final List<dynamic> decoded = json.decode(friendsJson);
      return decoded.map((item) => Friend.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveFriends(List<Friend> friends) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(
        friends.map((friend) => friend.toJson()).toList(),
      );
      await prefs.setString(_friendsKey, encoded);
    } catch (e) {
      // Handle error
    }
  }

  Future<List<GroupExpense>> loadGroupExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? expensesJson = prefs.getString(_groupExpensesKey);

      if (expensesJson == null) {
        return [];
      }

      final List<dynamic> decoded = json.decode(expensesJson);
      return decoded.map((item) => GroupExpense.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveGroupExpenses(List<GroupExpense> expenses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(
        expenses.map((expense) => expense.toJson()).toList(),
      );
      await prefs.setString(_groupExpensesKey, encoded);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_friendsKey);
    await prefs.remove(_groupExpensesKey);
  }
}

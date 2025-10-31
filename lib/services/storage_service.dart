import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';

class StorageService {
  static const String _expensesKey = 'expenses';

  Future<List<Expense>> loadExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? expensesJson = prefs.getString(_expensesKey);
      
      if (expensesJson == null) {
        return [];
      }

      final List<dynamic> decoded = json.decode(expensesJson);
      return decoded.map((item) => Expense.fromJson(item)).toList();
    } catch (e) {
      print('Error loading expenses: $e');
      return [];
    }
  }

  Future<void> saveExpenses(List<Expense> expenses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(
        expenses.map((expense) => expense.toJson()).toList(),
      );
      await prefs.setString(_expensesKey, encoded);
    } catch (e) {
      print('Error saving expenses: $e');
    }
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_expensesKey);
  }
}

import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class ExpenseProvider with ChangeNotifier {
  List<Expense> _expenses = [];
  bool _isLoading = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  ExpenseCategory? _filterCategory;
  String _searchQuery = '';

  List<Expense> get expenses {
    return _applyFilters(_expenses);
  }

  bool get isLoading => _isLoading;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;
  ExpenseCategory? get filterCategory => _filterCategory;
  String get searchQuery => _searchQuery;

  List<Expense> _applyFilters(List<Expense> expenseList) {
    var filtered = List<Expense>.from(expenseList);

    // Apply date range filter
    if (_filterStartDate != null) {
      filtered = filtered.where((expense) {
        return expense.date.isAfter(
          _filterStartDate!.subtract(const Duration(days: 1)),
        );
      }).toList();
    }

    if (_filterEndDate != null) {
      filtered = filtered.where((expense) {
        return expense.date.isBefore(
          _filterEndDate!.add(const Duration(days: 1)),
        );
      }).toList();
    }

    // Apply category filter
    if (_filterCategory != null) {
      filtered = filtered.where((expense) {
        return expense.category == _filterCategory;
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((expense) {
        return expense.title.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            (expense.note?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false);
      }).toList();
    }

    // Sort by date (newest first)
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  double get totalExpenses {
    return expenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  double get monthlyTotal {
    final now = DateTime.now();
    final monthExpenses = expenses.where((expense) {
      return expense.date.year == now.year && expense.date.month == now.month;
    });
    return monthExpenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  Map<ExpenseCategory, double> get categoryTotals {
    final Map<ExpenseCategory, double> totals = {};

    for (var expense in expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }

    return totals;
  }

  Future<void> loadExpenses() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check if user is authenticated
      if (await AuthService.isLoggedIn()) {
        // Load from server
        _expenses = await DatabaseService.getExpenses();
      } else {
        // User not authenticated, show empty list
        _expenses = [];
      }
    } catch (e) {
      print('Error loading expenses: $e');
      _expenses = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    try {
      // Add to server if authenticated
      if (await AuthService.isLoggedIn()) {
        await DatabaseService.addExpense(expense);
        _expenses.add(expense);
      } else {
        throw Exception('User not authenticated');
      }
    } catch (e) {
      print('Error adding expense: $e');
      rethrow;
    }
    notifyListeners();
  }

  Future<void> updateExpense(String id, Expense updatedExpense) async {
    try {
      final index = _expenses.indexWhere((expense) => expense.id == id);
      if (index != -1) {
        // Update on server if authenticated
        if (await AuthService.isLoggedIn()) {
          await DatabaseService.updateExpense(updatedExpense);
          _expenses[index] = updatedExpense;
        } else {
          throw Exception('User not authenticated');
        }
      }
    } catch (e) {
      print('Error updating expense: $e');
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    try {
      // Delete from server if authenticated
      if (await AuthService.isLoggedIn()) {
        await DatabaseService.deleteExpense(id);
        _expenses.removeWhere((expense) => expense.id == id);
      } else {
        throw Exception('User not authenticated');
      }
    } catch (e) {
      print('Error deleting expense: $e');
      rethrow;
    }
    notifyListeners();
  }

  void setDateFilter(DateTime? startDate, DateTime? endDate) {
    _filterStartDate = startDate;
    _filterEndDate = endDate;
    notifyListeners();
  }

  void setCategoryFilter(ExpenseCategory? category) {
    _filterCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _filterStartDate = null;
    _filterEndDate = null;
    _filterCategory = null;
    _searchQuery = '';
    notifyListeners();
  }

  Expense? getExpenseById(String id) {
    try {
      return _expenses.firstWhere((expense) => expense.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Expense> getExpensesByDateRange(DateTime start, DateTime end) {
    return _expenses.where((expense) {
      return expense.date.isAfter(start.subtract(const Duration(days: 1))) &&
          expense.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }
}

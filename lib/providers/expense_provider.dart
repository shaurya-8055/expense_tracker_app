import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';

class ExpenseProvider with ChangeNotifier {
  List<Expense> _expenses = [];
  final StorageService _storageService = StorageService();
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

    _expenses = await _storageService.loadExpenses();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    _expenses.add(expense);
    await _storageService.saveExpenses(_expenses);
    notifyListeners();
  }

  Future<void> updateExpense(String id, Expense updatedExpense) async {
    final index = _expenses.indexWhere((expense) => expense.id == id);
    if (index != -1) {
      _expenses[index] = updatedExpense;
      await _storageService.saveExpenses(_expenses);
      notifyListeners();
    }
  }

  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((expense) => expense.id == id);
    await _storageService.saveExpenses(_expenses);
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

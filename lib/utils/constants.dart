import 'package:flutter/material.dart';
import '../models/expense.dart';

class AppColors {
  static const primary = Color(0xFF6C5CE7);
  static const secondary = Color(0xFFA29BFE);
  static const accent = Color(0xFFFF7675);
  static const background = Color(0xFFF8F9FA);
  static const cardBackground = Colors.white;
  static const textPrimary = Color(0xFF2D3436);
  static const textSecondary = Color(0xFF636E72);
  static const success = Color(0xFF00B894);
  static const warning = Color(0xFFFDCB6E);
  static const error = Color(0xFFFF7675);

  // Category Colors
  static const food = Color(0xFFFF6B6B);
  static const transport = Color(0xFF4ECDC4);
  static const shopping = Color(0xFFFECA57);
  static const bills = Color(0xFF5F27CD);
  static const entertainment = Color(0xFFEE5A6F);
  static const health = Color(0xFF00D2D3);
  static const education = Color(0xFF1DD1A1);
  static const other = Color(0xFF95A5A6);
}

class CategoryConfig {
  static Color getCategoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return AppColors.food;
      case ExpenseCategory.transport:
        return AppColors.transport;
      case ExpenseCategory.shopping:
        return AppColors.shopping;
      case ExpenseCategory.bills:
        return AppColors.bills;
      case ExpenseCategory.entertainment:
        return AppColors.entertainment;
      case ExpenseCategory.health:
        return AppColors.health;
      case ExpenseCategory.education:
        return AppColors.education;
      case ExpenseCategory.other:
        return AppColors.other;
    }
  }

  static IconData getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant;
      case ExpenseCategory.transport:
        return Icons.directions_car;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag;
      case ExpenseCategory.bills:
        return Icons.receipt_long;
      case ExpenseCategory.entertainment:
        return Icons.movie;
      case ExpenseCategory.health:
        return Icons.medical_services;
      case ExpenseCategory.education:
        return Icons.school;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }
}

class AppStrings {
  static const appName = 'Expense Tracker';
  static const addExpense = 'Add Expense';
  static const editExpense = 'Edit Expense';
  static const deleteExpense = 'Delete Expense';
  static const totalExpenses = 'Total Expenses';
  static const thisMonth = 'This Month';
  static const noExpenses = 'No expenses yet';
  static const addFirstExpense = 'Tap + to add your first expense';
}

// Server Configuration
class ServerConfig {
  // Use 10.0.2.2 for Android emulator to access localhost
  static const String baseUrl = 'http://10.0.2.2:8080';
  static const String wsUrl = 'ws://10.0.2.2:8080';
  
  // API Endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authProfile = '/auth/profile';
  static const String authChangePassword = '/auth/change-password';
  static const String authVerifyPhone = '/auth/verify-phone';
  
  // Connection timeout
  static const Duration timeout = Duration(seconds: 30);
}

// Global access to base URL
const String baseUrl = ServerConfig.baseUrl;
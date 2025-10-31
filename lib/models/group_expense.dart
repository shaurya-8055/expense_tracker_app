import 'package:intl/intl.dart';
import 'expense.dart';

class Friend {
  final String id;
  final String name;
  final String? email;
  final String? phoneNumber;
  final String? avatarUrl;

  Friend({
    required this.id,
    required this.name,
    this.email,
    this.phoneNumber,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
    };
  }

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      avatarUrl: json['avatarUrl'],
    );
  }
}

class GroupExpense {
  final String id;
  final String title;
  final double totalAmount;
  final DateTime date;
  final ExpenseCategory category;
  final String paidBy; // Friend ID
  final List<String> participants; // Friend IDs
  final Map<String, double> splits; // Friend ID -> amount they owe
  final String? note;

  GroupExpense({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.date,
    required this.category,
    required this.paidBy,
    required this.participants,
    required this.splits,
    this.note,
  });

  String get formattedDate => DateFormat('MMM dd, yyyy').format(date);

  String get formattedAmount => '₹${totalAmount.toStringAsFixed(2)}';

  String get categoryName {
    return category.name[0].toUpperCase() + category.name.substring(1);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'totalAmount': totalAmount,
      'date': date.toIso8601String(),
      'category': category.index,
      'paidBy': paidBy,
      'participants': participants,
      'splits': splits,
      'note': note,
    };
  }

  factory GroupExpense.fromJson(Map<String, dynamic> json) {
    return GroupExpense(
      id: json['id'],
      title: json['title'],
      totalAmount: json['totalAmount'],
      date: DateTime.parse(json['date']),
      category: ExpenseCategory.values[json['category']],
      paidBy: json['paidBy'],
      participants: List<String>.from(json['participants']),
      splits: Map<String, double>.from(json['splits']),
      note: json['note'],
    );
  }

  GroupExpense copyWith({
    String? id,
    String? title,
    double? totalAmount,
    DateTime? date,
    ExpenseCategory? category,
    String? paidBy,
    List<String>? participants,
    Map<String, double>? splits,
    String? note,
  }) {
    return GroupExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      category: category ?? this.category,
      paidBy: paidBy ?? this.paidBy,
      participants: participants ?? this.participants,
      splits: splits ?? this.splits,
      note: note ?? this.note,
    );
  }
}

class Settlement {
  final String fromFriendId;
  final String toFriendId;
  final double amount;

  Settlement({
    required this.fromFriendId,
    required this.toFriendId,
    required this.amount,
  });

  String get formattedAmount => '₹${amount.toStringAsFixed(2)}';
}

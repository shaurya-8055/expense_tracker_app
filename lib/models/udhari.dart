import 'package:intl/intl.dart';

enum UdhariType {
  given, // Money you lent to someone (you'll receive)
  taken, // Money you borrowed from someone (you need to pay)
}

enum UdhariStatus {
  pending,
  partiallyPaid,
  settled,
}

class Udhari {
  final String id;
  final String personName;
  final double amount;
  final double amountPaid;
  final DateTime date;
  final DateTime? dueDate;
  final UdhariType type;
  final UdhariStatus status;
  final String? note;
  final String? phoneNumber;

  Udhari({
    required this.id,
    required this.personName,
    required this.amount,
    this.amountPaid = 0,
    required this.date,
    this.dueDate,
    required this.type,
    this.status = UdhariStatus.pending,
    this.note,
    this.phoneNumber,
  });

  double get remainingAmount => amount - amountPaid;

  bool get isSettled => status == UdhariStatus.settled || remainingAmount <= 0;

  String get formattedDate => DateFormat('MMM dd, yyyy').format(date);

  String get formattedDueDate =>
      dueDate != null ? DateFormat('MMM dd, yyyy').format(dueDate!) : 'No due date';

  String get formattedAmount => '₹${amount.toStringAsFixed(2)}';

  String get formattedRemainingAmount => '₹${remainingAmount.toStringAsFixed(2)}';

  String get formattedAmountPaid => '₹${amountPaid.toStringAsFixed(2)}';

  String get typeText => type == UdhariType.given ? 'You Lent' : 'You Borrowed';

  String get statusText {
    if (isSettled) return 'Settled';
    if (status == UdhariStatus.partiallyPaid) return 'Partially Paid';
    return 'Pending';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'personName': personName,
      'amount': amount,
      'amountPaid': amountPaid,
      'date': date.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'type': type.index,
      'status': status.index,
      'note': note,
      'phoneNumber': phoneNumber,
    };
  }

  factory Udhari.fromJson(Map<String, dynamic> json) {
    return Udhari(
      id: json['id'],
      personName: json['personName'],
      amount: json['amount'],
      amountPaid: json['amountPaid'] ?? 0,
      date: DateTime.parse(json['date']),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      type: UdhariType.values[json['type']],
      status: UdhariStatus.values[json['status'] ?? 0],
      note: json['note'],
      phoneNumber: json['phoneNumber'],
    );
  }

  Udhari copyWith({
    String? id,
    String? personName,
    double? amount,
    double? amountPaid,
    DateTime? date,
    DateTime? dueDate,
    UdhariType? type,
    UdhariStatus? status,
    String? note,
    String? phoneNumber,
  }) {
    return Udhari(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      amountPaid: amountPaid ?? this.amountPaid,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      type: type ?? this.type,
      status: status ?? this.status,
      note: note ?? this.note,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

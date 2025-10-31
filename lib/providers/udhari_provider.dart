import 'package:flutter/foundation.dart';
import '../models/udhari.dart';
import '../services/udhari_storage_service.dart';

class UdhariProvider with ChangeNotifier {
  List<Udhari> _udharis = [];
  final UdhariStorageService _storageService = UdhariStorageService();
  bool _isLoading = false;

  List<Udhari> get udharis => _udharis;
  bool get isLoading => _isLoading;

  List<Udhari> get givenUdharis {
    return _udharis.where((u) => u.type == UdhariType.given).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Udhari> get takenUdharis {
    return _udharis.where((u) => u.type == UdhariType.taken).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Udhari> get pendingUdharis {
    return _udharis.where((u) => !u.isSettled).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  double get totalGiven {
    return givenUdharis.fold(0, (sum, u) => sum + u.remainingAmount);
  }

  double get totalTaken {
    return takenUdharis.fold(0, (sum, u) => sum + u.remainingAmount);
  }

  double get netBalance => totalGiven - totalTaken;

  Future<void> loadUdharis() async {
    _isLoading = true;
    notifyListeners();

    _udharis = await _storageService.loadUdharis();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addUdhari(Udhari udhari) async {
    _udharis.add(udhari);
    await _storageService.saveUdharis(_udharis);
    notifyListeners();
  }

  Future<void> updateUdhari(String id, Udhari updatedUdhari) async {
    final index = _udharis.indexWhere((u) => u.id == id);
    if (index != -1) {
      _udharis[index] = updatedUdhari;
      await _storageService.saveUdharis(_udharis);
      notifyListeners();
    }
  }

  Future<void> deleteUdhari(String id) async {
    _udharis.removeWhere((u) => u.id == id);
    await _storageService.saveUdharis(_udharis);
    notifyListeners();
  }

  Future<void> addPayment(String id, double amount) async {
    final index = _udharis.indexWhere((u) => u.id == id);
    if (index != -1) {
      final udhari = _udharis[index];
      final newAmountPaid = udhari.amountPaid + amount;
      
      UdhariStatus newStatus;
      if (newAmountPaid >= udhari.amount) {
        newStatus = UdhariStatus.settled;
      } else if (newAmountPaid > 0) {
        newStatus = UdhariStatus.partiallyPaid;
      } else {
        newStatus = UdhariStatus.pending;
      }

      _udharis[index] = udhari.copyWith(
        amountPaid: newAmountPaid,
        status: newStatus,
      );
      
      await _storageService.saveUdharis(_udharis);
      notifyListeners();
    }
  }

  Future<void> settleUdhari(String id) async {
    final index = _udharis.indexWhere((u) => u.id == id);
    if (index != -1) {
      _udharis[index] = _udharis[index].copyWith(
        amountPaid: _udharis[index].amount,
        status: UdhariStatus.settled,
      );
      await _storageService.saveUdharis(_udharis);
      notifyListeners();
    }
  }

  Udhari? getUdhariById(String id) {
    try {
      return _udharis.firstWhere((u) => u.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Udhari> getUdharisByPerson(String personName) {
    return _udharis.where((u) => 
      u.personName.toLowerCase().contains(personName.toLowerCase())
    ).toList();
  }
}

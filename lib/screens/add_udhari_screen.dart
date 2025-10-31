import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/udhari.dart';
import '../providers/udhari_provider.dart';
import '../utils/constants.dart';
import '../screens/contact_picker_screen.dart';
import '../services/contact_service.dart';

class AddUdhariScreen extends StatefulWidget {
  final Udhari? udhari;

  const AddUdhariScreen({super.key, this.udhari});

  @override
  State<AddUdhariScreen> createState() => _AddUdhariScreenState();
}

class _AddUdhariScreenState extends State<AddUdhariScreen> {
  final _formKey = GlobalKey<FormState>();
  final _personNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _phoneController = TextEditingController();

  UdhariType _selectedType = UdhariType.given;
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedDueDate;

  bool get _isEditing => widget.udhari != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _personNameController.text = widget.udhari!.personName;
      _amountController.text = widget.udhari!.amount.toString();
      _noteController.text = widget.udhari!.note ?? '';
      _phoneController.text = widget.udhari!.phoneNumber ?? '';
      _selectedType = widget.udhari!.type;
      _selectedDate = widget.udhari!.date;
      _selectedDueDate = widget.udhari!.dueDate;
    }
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Udhari' : 'Add Udhari'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildTypeSelector(),
            const SizedBox(height: 20),
            _buildPersonNameField(),
            const SizedBox(height: 20),
            _buildAmountField(),
            const SizedBox(height: 20),
            _buildPhoneField(),
            const SizedBox(height: 20),
            _buildDateSelector(),
            const SizedBox(height: 20),
            _buildDueDateSelector(),
            const SizedBox(height: 20),
            _buildNoteField(),
            const SizedBox(height: 32),
            _buildSaveButton(),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              _buildDeleteButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTypeOption(
                    UdhariType.given,
                    'You Lent',
                    'Money you gave',
                    Icons.arrow_downward,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeOption(
                    UdhariType.taken,
                    'You Borrowed',
                    'Money you took',
                    Icons.arrow_upward,
                    AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(
    UdhariType type,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? color.withOpacity(0.7)
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonNameField() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Person Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showContactPicker,
                  icon: const Icon(Icons.contact_phone, size: 18),
                  label: const Text('From Contacts'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _personNameController,
              decoration: const InputDecoration(
                hintText: 'Enter person name or select from contacts',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter person name';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Amount',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                hintText: '0.00',
                prefixText: '₹ ',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _selectedType == UdhariType.given
                    ? AppColors.success
                    : AppColors.error,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phone Number (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Enter phone number',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                prefixIcon: Icon(Icons.phone, size: 20),
              ),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Udhari(
                        id: '',
                        personName: '',
                        amount: 0,
                        date: _selectedDate,
                        type: UdhariType.given,
                      ).formattedDate,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDueDateSelector() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _selectDueDate,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.alarm,
                  color: AppColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Due Date (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedDueDate != null
                          ? Udhari(
                              id: '',
                              personName: '',
                              amount: 0,
                              date: _selectedDueDate!,
                              type: UdhariType.given,
                            ).formattedDate
                          : 'No due date set',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDueDate != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedDueDate != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _selectedDueDate = null;
                    });
                  },
                  color: AppColors.textSecondary,
                )
              else
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Note (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add a note...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveUdhari,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: Text(
        _isEditing ? 'Update Udhari' : 'Add Udhari',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return OutlinedButton(
      onPressed: _deleteUdhari,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'Delete Udhari',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.warning,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  void _saveUdhari() {
    if (_formKey.currentState!.validate()) {
      final udhari = Udhari(
        id: _isEditing ? widget.udhari!.id : const Uuid().v4(),
        personName: _personNameController.text.trim(),
        amount: double.parse(_amountController.text),
        amountPaid: _isEditing ? widget.udhari!.amountPaid : 0,
        date: _selectedDate,
        dueDate: _selectedDueDate,
        type: _selectedType,
        status: _isEditing ? widget.udhari!.status : UdhariStatus.pending,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );

      final provider = Provider.of<UdhariProvider>(context, listen: false);

      if (_isEditing) {
        provider.updateUdhari(widget.udhari!.id, udhari);
      } else {
        provider.addUdhari(udhari);
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Udhari updated' : 'Udhari added'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _deleteUdhari() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Udhari'),
        content: const Text(
          'Are you sure you want to delete this udhari record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<UdhariProvider>(
                context,
                listen: false,
              ).deleteUdhari(widget.udhari!.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Udhari deleted'),
                  duration: Duration(seconds: 2),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _showContactPicker() async {
    try {
      final result = await Navigator.push<List<ContactMatch>>(
        context,
        MaterialPageRoute(
          builder: (context) => const ContactPickerScreen(isForInvite: false),
        ),
      );

      if (result != null && result.isNotEmpty) {
        final selectedContact = result.first;
        setState(() {
          _personNameController.text = selectedContact.displayName;
          _phoneController.text = selectedContact.primaryPhone;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

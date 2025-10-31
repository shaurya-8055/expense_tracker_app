import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/udhari.dart';
import '../providers/expense_provider.dart';
import '../providers/udhari_provider.dart';
import '../utils/constants.dart';
import '../widgets/expense_card.dart';
import '../widgets/connection_status_widgets.dart';
import '../services/pdf_service.dart';
import 'add_expense_screen.dart';
import 'statistics_screen.dart';
import 'udhari_screen.dart';
import 'group_expense_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<ExpenseProvider>(context, listen: false).loadExpenses();
      Provider.of<UdhariProvider>(context, listen: false).loadUdharis();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _searchController.clear();
      if (index == 0) {
        Provider.of<ExpenseProvider>(context, listen: false).setSearchQuery('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildExpensesPage(),
      const UdhariScreen(),
      const GroupExpenseScreen(),
      const StatisticsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Udhari',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Split'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Stats'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddExpenseScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildExpensesPage() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SyncStatusBanner()),
          const SliverToBoxAdapter(child: RealTimeUpdateBanner()),
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildSummaryCard()),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildFilterChips()),
          _buildExpensesList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.05),
            AppColors.secondary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.appName,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getCurrentDate(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const ConnectionStatusWidget(),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _showExportOptions,
              tooltip: 'Export to PDF',
              color: AppColors.primary,
              iconSize: 24,
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Widget _buildSummaryCard() {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.thisMonth,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${provider.monthlyTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${provider.expenses.length} transactions',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          return TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search expenses...',
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        provider.setSearchQuery('');
                      },
                      color: AppColors.textSecondary,
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: (value) {
              provider.setSearchQuery(value);
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildFilterChip('All', null, provider),
              const SizedBox(width: 8),
              ...ExpenseCategory.values.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(
                    category.name[0].toUpperCase() + category.name.substring(1),
                    category,
                    provider,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
    String label,
    ExpenseCategory? category,
    ExpenseProvider provider,
  ) {
    final isSelected = provider.filterCategory == category;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        provider.setCategoryFilter(selected ? category : null);
      },
      selectedColor: category != null
          ? CategoryConfig.getCategoryColor(category).withOpacity(0.2)
          : AppColors.primary.withOpacity(0.2),
      backgroundColor: Colors.white,
      checkmarkColor: category != null
          ? CategoryConfig.getCategoryColor(category)
          : AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? (category != null
                  ? CategoryConfig.getCategoryColor(category)
                  : AppColors.primary)
            : AppColors.textSecondary,
      ),
      side: BorderSide(
        color: isSelected
            ? (category != null
                  ? CategoryConfig.getCategoryColor(category)
                  : AppColors.primary)
            : Colors.grey.shade300,
        width: isSelected ? 1.5 : 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildExpensesList() {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.expenses.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 100,
                    color: AppColors.textSecondary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    AppStrings.noExpenses,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.addFirstExpense,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final expense = provider.expenses[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ExpenseCard(
                  expense: expense,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddExpenseScreen(expense: expense),
                      ),
                    );
                  },
                  onDelete: () {
                    _showDeleteConfirmation(expense);
                  },
                ),
              );
            }, childCount: provider.expenses.length),
          ),
        );
      },
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export Data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt, color: AppColors.primary),
              ),
              title: const Text('Export Expenses'),
              subtitle: const Text('Export all expenses to PDF'),
              onTap: () async {
                Navigator.pop(context);
                final provider = Provider.of<ExpenseProvider>(
                  context,
                  listen: false,
                );
                await _exportExpenses(provider.expenses);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.warning,
                ),
              ),
              title: const Text('Export Udhari'),
              subtitle: const Text('Export all Udhari records to PDF'),
              onTap: () async {
                Navigator.pop(context);
                final provider = Provider.of<UdhariProvider>(
                  context,
                  listen: false,
                );
                await _exportUdhari(provider.udharis);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportExpenses(List<Expense> expenses) async {
    try {
      await PdfService.exportExpensesToPdf(expenses);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expenses exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportUdhari(List<Udhari> udharis) async {
    try {
      await PdfService.exportUdhariToPdf(udharis);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Udhari exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<ExpenseProvider>(
                context,
                listen: false,
              ).deleteExpense(expense.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Expense deleted'),
                  duration: Duration(seconds: 2),
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
}

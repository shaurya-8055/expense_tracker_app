// App Configuration and Usage Guide
// =================================

/*
 * EXPENSE TRACKER APP - STRUCTURE OVERVIEW
 * 
 * This is a comprehensive expense tracking application with the following architecture:
 * 
 * 1. MODELS (Data Layer)
 *    - expense.dart: Core data model with categories, validation, and formatting
 * 
 * 2. PROVIDERS (Business Logic)
 *    - expense_provider.dart: State management, filtering, calculations
 * 
 * 3. SERVICES (Data Persistence)
 *    - storage_service.dart: Local data storage using SharedPreferences
 * 
 * 4. SCREENS (UI Pages)
 *    - home_screen.dart: Main dashboard with expense list
 *    - add_expense_screen.dart: Form for adding/editing expenses
 *    - statistics_screen.dart: Analytics and visualizations
 * 
 * 5. WIDGETS (Reusable Components)
 *    - expense_card.dart: Individual expense display card
 *    - category_chart.dart: Pie chart and category legend
 * 
 * 6. UTILS (Constants & Helpers)
 *    - constants.dart: Colors, category configs, app strings
 * 
 * FEATURES:
 * =========
 * ✓ Add, edit, delete expenses
 * ✓ 8 expense categories with unique colors/icons
 * ✓ Search and filter functionality
 * ✓ Date range filtering
 * ✓ Swipe-to-delete gesture
 * ✓ Statistics with pie charts
 * ✓ Period-based analysis (week/month/year)
 * ✓ Local data persistence
 * ✓ Beautiful Material Design 3 UI
 * 
 * DATA FLOW:
 * ==========
 * User Action → Screen → Provider → Service → Storage
 *                  ↑                    ↓
 *                  └────── UI Update ───┘
 * 
 * CATEGORIES:
 * ===========
 * 1. Food        - Red       - Restaurant icon
 * 2. Transport   - Teal      - Car icon
 * 3. Shopping    - Yellow    - Shopping bag icon
 * 4. Bills       - Purple    - Receipt icon
 * 5. Entertainment - Pink    - Movie icon
 * 6. Health      - Cyan      - Medical icon
 * 7. Education   - Green     - School icon
 * 8. Other       - Gray      - More icon
 * 
 * NAVIGATION:
 * ===========
 * Bottom Navigation:
 *   - Expenses (List view)
 *   - Statistics (Analytics view)
 * 
 * FAB: Add Expense (available on both tabs)
 * 
 * TESTING THE APP:
 * ================
 * 1. Run: flutter run
 * 2. Tap "+" to add your first expense
 * 3. Fill in the form (title, amount, category, date)
 * 4. View it in the main list
 * 5. Tap Statistics to see charts
 * 6. Use search/filter to organize expenses
 * 7. Swipe left to delete, or tap to edit
 * 
 * CUSTOMIZATION:
 * ==============
 * To customize colors:
 *   - Edit lib/utils/constants.dart (AppColors class)
 * 
 * To add new categories:
 *   - Add to ExpenseCategory enum in lib/models/expense.dart
 *   - Add color in CategoryConfig.getCategoryColor()
 *   - Add icon in CategoryConfig.getCategoryIcon()
 * 
 * To modify storage:
 *   - Edit lib/services/storage_service.dart
 *   - Can switch to SQLite, Hive, or Firebase
 * 
 * PERFORMANCE:
 * ============
 * - Efficient Provider state management
 * - Minimal rebuilds with Consumer widgets
 * - Lazy loading with ListView.builder
 * - JSON serialization for fast storage
 * - No unnecessary network calls (fully offline)
 * 
 * BEST PRACTICES IMPLEMENTED:
 * ===========================
 * ✓ Separation of concerns
 * ✓ Single responsibility principle
 * ✓ DRY (Don't Repeat Yourself)
 * ✓ Consistent naming conventions
 * ✓ Proper error handling
 * ✓ Form validation
 * ✓ User feedback (SnackBars)
 * ✓ Responsive design
 * ✓ Accessibility considerations
 * ✓ Code documentation
 */

// Example: How to add a new expense programmatically
void exampleAddExpense() {
  /*
  final expense = Expense(
    id: const Uuid().v4(),
    title: 'Coffee',
    amount: 4.50,
    date: DateTime.now(),
    category: ExpenseCategory.food,
    note: 'Morning coffee at Starbucks',
  );
  
  Provider.of<ExpenseProvider>(context, listen: false).addExpense(expense);
  */
}

// Example: How to filter expenses
void exampleFilter() {
  /*
  final provider = Provider.of<ExpenseProvider>(context, listen: false);
  
  // Filter by category
  provider.setCategoryFilter(ExpenseCategory.food);
  
  // Filter by date range
  final startDate = DateTime(2024, 1, 1);
  final endDate = DateTime(2024, 12, 31);
  provider.setDateFilter(startDate, endDate);
  
  // Search
  provider.setSearchQuery('coffee');
  
  // Clear all filters
  provider.clearFilters();
  */
}

// Example: How to get statistics
void exampleStats() {
  /*
  final provider = Provider.of<ExpenseProvider>(context, listen: false);
  
  // Get total expenses
  final total = provider.totalExpenses;
  
  // Get monthly total
  final monthlyTotal = provider.monthlyTotal;
  
  // Get category totals
  final categoryTotals = provider.categoryTotals;
  
  // Get expenses by date range
  final expenses = provider.getExpensesByDateRange(startDate, endDate);
  */
}

# 💰 Expense Tracker App

A beautiful, feature-rich expense tracking application built with Flutter. Track your spending, manage credit/debt (Udhari), split expenses with friends (like Splitwise), and visualize your expenses with charts.

**Currency: Indian Rupee (₹)**

## ✨ Features

### 📊 Personal Expense Tracking

- **Add/Edit/Delete Expenses**: Easily manage your expenses with a clean, intuitive interface
- **Category Management**: Organize expenses into 8 categories:
  - 🍔 Food
  - 🚗 Transport
  - 🛍️ Shopping
  - 📄 Bills
  - 🎬 Entertainment
  - 💊 Health
  - 📚 Education
  - 📦 Other

### 💳 Udhari Management (Credit/Debt Tracking)

- **Track Money Lent**: Keep track of money you've lent to others
- **Track Money Borrowed**: Monitor money you've borrowed
- **Payment Tracking**: Record partial payments
- **Due Date Reminders**: Set and track due dates
- **Settlement**: Mark transactions as settled
- **Net Balance**: See your overall lending/borrowing position
- **Contact Info**: Store phone numbers for easy follow-up

### 👥 Group Expenses (Splitwise-like Feature)

- **Add Friends**: Manage your friend list
- **Split Expenses**: Divide expenses among group members
- **Flexible Splits**: Custom split amounts or equal division
- **Balance Tracking**: See who owes whom
- **Settlement Suggestions**: Smart algorithms to minimize transactions
- **Expense History**: Track all group expenses with friends

### 📈 Analytics & Visualization

- **Interactive Pie Charts**: Visualize spending by category
- **Period-based Statistics**: View expenses by week, month, or year
- **Category Breakdown**: Detailed breakdown with percentages and progress bars
- **Monthly Summary**: Quick overview of current month's spending
- **Udhari Overview**: Visual summary of money owed and owing

### 🔍 Advanced Features

- **Search**: Find expenses quickly by title or notes
- **Filter by Category**: Focus on specific expense categories
- **Date Range Filtering**: View expenses within custom date ranges
- **Swipe to Delete**: Quick gesture-based deletion
- **Persistent Storage**: All data saved locally using SharedPreferences
- **Multi-tab Interface**: Easy navigation between different features

### 🎨 Beautiful UI

- **Modern Material Design 3**: Clean, contemporary interface
- **Gradient Cards**: Eye-catching visual elements
- **Color-coded Categories**: Each category has unique colors and icons
- **Smooth Animations**: Polished user experience
- **Responsive Layout**: Works great on all screen sizes
- **Quick Action Buttons**: Fast access to frequently used features

## ✨ Features

### 📊 Core Functionality

- **Add/Edit/Delete Expenses**: Easily manage your expenses with a clean, intuitive interface
- **Category Management**: Organize expenses into 8 categories:
  - 🍔 Food
  - 🚗 Transport
  - 🛍️ Shopping
  - 📄 Bills
  - 🎬 Entertainment
  - 💊 Health
  - 📚 Education
  - 📦 Other

### 📈 Analytics & Visualization

- **Interactive Pie Charts**: Visualize spending by category
- **Period-based Statistics**: View expenses by week, month, or year
- **Category Breakdown**: Detailed breakdown with percentages and progress bars
- **Monthly Summary**: Quick overview of current month's spending

### 🔍 Advanced Features

- **Search**: Find expenses quickly by title or notes
- **Filter by Category**: Focus on specific expense categories
- **Date Range Filtering**: View expenses within custom date ranges
- **Swipe to Delete**: Quick gesture-based deletion
- **Persistent Storage**: All data saved locally using SharedPreferences

### 🎨 Beautiful UI

- **Modern Material Design 3**: Clean, contemporary interface
- **Gradient Cards**: Eye-catching visual elements
- **Color-coded Categories**: Each category has unique colors and icons
- **Smooth Animations**: Polished user experience
- **Responsive Layout**: Works great on all screen sizes

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point with multi-provider setup
├── models/
│   ├── expense.dart         # Personal expense data model
│   ├── udhari.dart          # Credit/Debt tracking model
│   └── group_expense.dart   # Group expense & friend models
├── providers/
│   ├── expense_provider.dart       # Personal expense state management
│   ├── udhari_provider.dart        # Udhari state management
│   └── group_expense_provider.dart # Group expense state management
├── screens/
│   ├── home_screen.dart          # Main dashboard with quick actions
│   ├── add_expense_screen.dart   # Add/Edit personal expense
│   ├── statistics_screen.dart    # Analytics and charts
│   ├── udhari_screen.dart        # Udhari management screen
│   └── add_udhari_screen.dart    # Add/Edit udhari
├── widgets/
│   ├── expense_card.dart    # Individual expense display card
│   └── category_chart.dart  # Pie chart and legend
├── services/
│   ├── storage_service.dart             # Expense local storage
│   ├── udhari_storage_service.dart      # Udhari local storage
│   └── group_expense_storage_service.dart # Group expense local storage
└── utils/
    └── constants.dart       # App constants, colors, configs
```

## 🛠️ Technologies Used

- **Framework**: Flutter SDK
- **State Management**: Provider
- **Local Storage**: SharedPreferences
- **Charts**: FL Chart
- **Date Formatting**: Intl
- **Unique IDs**: UUID

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1 # State management
  shared_preferences: ^2.2.2 # Local storage
  fl_chart: ^0.66.0 # Charts
  intl: ^0.19.0 # Date formatting
  uuid: ^4.3.3 # Unique IDs
  cupertino_icons: ^1.0.8 # iOS icons
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Android Studio / VS Code
- Android Emulator or iOS Simulator

### Installation

1. **Clone the repository**

   ```bash
   git clone <your-repo-url>
   cd expense_tracker_app
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## 📱 How to Use

### Adding an Expense

1. Tap the **"+ Add Expense"** button
2. Enter expense details:
   - Title (required)
   - Amount (required)
   - Category (select from 8 options)
   - Date (tap to change)
   - Note (optional)
3. Tap **"Add Expense"** to save

### Managing Udhari (Credit/Debt)

1. From home screen, tap **"Udhari"** quick action button
2. View summary of money lent and borrowed
3. Use tabs to filter: All / Given / Taken
4. **Add new udhari:**
   - Tap "+" button
   - Select type: "You Lent" or "You Borrowed"
   - Enter person name, amount, due date (optional)
   - Add note and phone number (optional)
5. **Record payments:**
   - Tap "Add Payment" on any udhari
   - Enter amount paid
6. **Settle udhari:**
   - Tap "Settle" to mark as fully paid

### Split Expenses with Friends

1. From home screen, tap **"Split Expense"** (Coming Soon)
2. Add friends to your list
3. Create group expenses:
   - Enter expense details
   - Select who paid
   - Choose participants
   - Split equally or custom amounts
4. View balances with each friend
5. Get settlement suggestions
6. Track expense history with friends

### Editing an Expense

1. Tap on any expense card in the list
2. Modify the details
3. Tap **"Update Expense"** to save changes

### Deleting an Expense

- **Swipe left** on any expense card, OR
- Open the expense and tap **"Delete Expense"**

### Filtering & Search

1. Tap the **filter icon** in the header
2. Select a category to filter by
3. Use the search bar to find expenses by title or note
4. Tap **"Clear All"** to remove filters

### Viewing Statistics

1. Tap the **"Statistics"** tab at the bottom
2. Switch between **This Week**, **This Month**, or **This Year**
3. View:
   - Total spending for the period
   - Pie chart by category
   - Detailed category breakdown with percentages

## 🎨 Color Scheme

- **Primary**: Purple (#6C5CE7)
- **Secondary**: Light Purple (#A29BFE)
- **Accent**: Coral (#FF7675)
- **Background**: Light Gray (#F8F9FA)

### Category Colors

- Food: Red (#FF6B6B)
- Transport: Teal (#4ECDC4)
- Shopping: Yellow (#FECA57)
- Bills: Purple (#5F27CD)
- Entertainment: Pink (#EE5A6F)
- Health: Cyan (#00D2D3)
- Education: Green (#1DD1A1)
- Other: Gray (#95A5A6)

## 🏛️ Architecture

The app follows **Clean Architecture** principles:

- **Models**: Define data structures
- **Providers**: Handle business logic and state
- **Services**: Manage external dependencies (storage)
- **Screens**: UI pages
- **Widgets**: Reusable UI components
- **Utils**: Constants and helper functions

### State Management

Uses **Provider** pattern for:

- Centralized expense management
- Reactive UI updates
- Efficient rebuilds
- Easy testing

## 🔒 Data Persistence

All expenses are stored locally using **SharedPreferences**:

- Automatic saving on add/edit/delete
- JSON serialization
- No internet required
- Privacy-focused (data never leaves device)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is open source and available under the MIT License.

## 👨‍💻 Developer

Built with ❤️ using Flutter

---

**Happy Expense Tracking! 💸**

# Expense Tracker App

A comprehensive expense tracking application built with Flutter that helps you manage your personal finances.

## Features

- **Dashboard**
  - Quick overview of income and expenses
  - Easy transaction entry with category selection
  - Real-time balance updates

- **Reports**
  - Visual representation of expenses by category
  - Period-based analysis (Week/Month/Quarter/Year)
  - Pie charts for expense distribution

- **Transaction History**
  - Searchable and filterable transaction list
  - Category and type-based filtering
  - Detailed transaction view with notes

- **Budget Management**
  - Set overall and category-specific budgets
  - Visual progress tracking
  - Budget alerts and notifications

## Prerequisites

- Flutter SDK (latest version)
- Android Studio / VS Code with Flutter extensions
- Android SDK for Android deployment
- iOS development tools for iOS deployment (Mac only)

## Getting Started

1. Clone the repository:
```bash
git clone [repository-url]
cd expense_tracker
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── models/
│   ├── transaction.dart
│   └── budget.dart
├── screens/
│   ├── home_screen.dart
│   ├── dashboard_screen.dart
│   ├── reports_screen.dart
│   ├── history_screen.dart
│   └── budget_screen.dart
├── services/
│   └── database_helper.dart
├── utils/
│   └── constants.dart
└── main.dart
```

## Dependencies

- `sqflite`: Local database storage
- `fl_chart`: Chart visualizations
- `intl`: Date and number formatting
- `provider`: State management
- `flutter_local_notifications`: Push notifications

## Database Schema

### Transactions Table
```sql
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount REAL NOT NULL,
  isExpense INTEGER NOT NULL,
  date TEXT NOT NULL,
  category TEXT NOT NULL,
  note TEXT
)
```

### Budgets Table
```sql
CREATE TABLE budgets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount REAL NOT NULL,
  category TEXT,
  startDate TEXT NOT NULL,
  endDate TEXT NOT NULL
)
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 
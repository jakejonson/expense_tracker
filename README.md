# Expense Tracker

A comprehensive expense tracking application built with Flutter that helps users manage their finances effectively.

## Features

- **Transaction Management**
  - Add, edit, and delete income and expenses
  - Categorize transactions
  - Add notes to transactions
  - Support for recurring transactions
  - Transaction history view

- **Budget Planning**
  - Set monthly budgets by category
  - Track spending against budgets
  - Visual budget progress indicators
  - Budget alerts when limits are exceeded

- **Reports & Analytics**
  - Monthly income and expense summaries
  - Category-wise spending breakdown
  - Visual charts and graphs
  - Export reports to Excel
  - Share reports via email or messaging apps

- **Data Management**
  - Local database storage
  - Data backup and restore
  - Import/Export functionality
  - Secure data handling

## Getting Started

### Prerequisites

- Flutter SDK (version 3.19.0 or higher)
- Dart SDK (version 3.0.0 or higher)
- Android Studio / VS Code with Flutter extensions
- Git

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/expense_tracker.git
   ```

2. Navigate to the project directory:
   ```bash
   cd expense_tracker
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Testing

The project includes a comprehensive test suite covering unit tests, widget tests, and integration tests.

### Running Tests

1. Run all tests:
   ```bash
   flutter test
   ```

2. Run tests with coverage:
   ```bash
   flutter test --coverage
   ```

3. Generate coverage report:
   ```bash
   genhtml coverage/lcov.info -o coverage/html
   ```

### Test Structure

- `test/models_test.dart`: Unit tests for data models
- `test/database_helper_test.dart`: Unit tests for database operations
- `test/reports_screen_test.dart`: Widget tests for the reports screen

### Test Coverage

The test suite covers:
- Data model validation
- Database CRUD operations
- UI component rendering
- State management
- Error handling
- Edge cases

## Continuous Integration

The project uses GitHub Actions for continuous integration. The workflow includes:

### Test Job
- Runs on every push to main and pull requests
- Verifies code formatting
- Runs static analysis
- Executes all tests with coverage
- Uploads coverage reports to Codecov

### Quality Job
- Runs after successful tests
- Performs additional code quality checks
- Verifies package dependencies
- Checks for outdated packages
- Validates pubspec.yaml

### Build Job
- Runs after successful tests and quality checks
- Builds release APK and App Bundle
- Uploads build artifacts for download

To set up the workflow:

1. Fork the repository
2. Add the following secrets to your repository:
   - `CODECOV_TOKEN`: Your Codecov token for coverage reporting

3. Enable GitHub Actions in your repository settings

The workflow will automatically run on:
- Every push to the main branch
- Every pull request targeting the main branch

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the amazing framework
- All contributors who have helped shape this project
- The open-source community for their valuable resources and tools 
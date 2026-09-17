import '../../application/ports/transaction_runner.dart';
import 'app_database.dart';

final class DriftTransactionRunner implements TransactionRunner {
  const DriftTransactionRunner(this._database);

  final AppDatabase _database;

  @override
  Future<T> run<T>(Future<T> Function() action) {
    return _database.transaction(action);
  }
}

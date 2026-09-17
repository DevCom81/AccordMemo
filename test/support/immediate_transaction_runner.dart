import 'package:accord_memo/application/ports/transaction_runner.dart';

final class ImmediateTransactionRunner implements TransactionRunner {
  const ImmediateTransactionRunner();

  @override
  Future<T> run<T>(Future<T> Function() action) => action();
}

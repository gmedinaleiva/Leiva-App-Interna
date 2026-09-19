import '../domain/expense_models.dart';
import 'expenses_api.dart';

abstract interface class ExpensesGateway {
  Future<ExpenseDashboard> dashboard();
  Future<ExpenseRubrics> rubrics();
  Future<ExpenseRecord> upload(ExpenseUploadDraft draft);
}

class ExpensesRepository implements ExpensesGateway {
  const ExpensesRepository(this._api);
  final ExpensesApi _api;

  @override
  Future<ExpenseDashboard> dashboard() => _api.dashboard();

  @override
  Future<ExpenseRubrics> rubrics() => _api.rubrics();

  @override
  Future<ExpenseRecord> upload(ExpenseUploadDraft draft) => _api.upload(draft);
}

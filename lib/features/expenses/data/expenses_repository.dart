import '../domain/expense_models.dart';
import 'expenses_api.dart';

abstract interface class ExpensesGateway {
  Future<ExpenseDashboard> dashboard();
  Future<ExpenseRubrics> rubrics();
  Future<ExpenseRecord> upload(ExpenseUploadDraft draft);
  Future<ExpenseRecord> record(int documentId);
  Future<ExpenseFile> file(int documentId);
  Future<ExpenseRecord> resubmit(int documentId);
  Future<ExpenseRecord> validateFuel(int documentId);
  Future<ExpenseRecord> saveFuelStatement(int documentId, String statement);
  Future<ExpensePeriod> submitPeriod(int periodId);
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

  @override
  Future<ExpenseRecord> record(int documentId) => _api.record(documentId);

  @override
  Future<ExpenseFile> file(int documentId) => _api.file(documentId);

  @override
  Future<ExpenseRecord> resubmit(int documentId) => _api.resubmit(documentId);

  @override
  Future<ExpenseRecord> validateFuel(int documentId) =>
      _api.validateFuel(documentId);

  @override
  Future<ExpenseRecord> saveFuelStatement(int documentId, String statement) =>
      _api.saveFuelStatement(documentId, statement);

  @override
  Future<ExpensePeriod> submitPeriod(int periodId) =>
      _api.submitPeriod(periodId);
}

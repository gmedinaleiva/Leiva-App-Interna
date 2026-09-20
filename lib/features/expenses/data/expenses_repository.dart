import '../domain/expense_models.dart';
import 'expenses_api.dart';

abstract interface class ExpensesGateway {
  Future<ExpenseDashboard> dashboard();
  Future<ExpenseRubrics> rubrics();
  Future<ExpenseRecord> upload(ExpenseUploadDraft draft);
  Future<List<PettyCashFund>> pettyCashFunds();
  Future<ExpenseRecord> record(int documentId);
  Future<ExpenseFile> file(int documentId);
  Future<ExpenseFile> report({
    required int periodId,
    String recordType = 'all',
  });
  Future<ExpenseRecord> resubmit(int documentId);
  Future<ExpenseRecord> validateFuel(int documentId);
  Future<ExpenseRecord> saveFuelStatement(int documentId, String statement);
  Future<ExpensePeriod> submitPeriod(int periodId);
  Future<ExpensePeriod> createTravelAdvance(TravelAdvanceDraft draft);
  Future<ExpenseRecord> updateRecord(int documentId, ExpenseUpdateDraft draft);
  Future<ExpensePeriod> requestAdvanceCorrection(
    int periodId,
    String observation,
  );
  Future<ExpensePeriod> confirmReceipt(int periodId, ExpenseReceiptDraft draft);
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
  Future<List<PettyCashFund>> pettyCashFunds() => _api.pettyCashFunds();

  @override
  Future<ExpenseRecord> record(int documentId) => _api.record(documentId);

  @override
  Future<ExpenseFile> file(int documentId) => _api.file(documentId);

  @override
  Future<ExpenseFile> report({
    required int periodId,
    String recordType = 'all',
  }) => _api.report(periodId: periodId, recordType: recordType);

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

  @override
  Future<ExpensePeriod> createTravelAdvance(TravelAdvanceDraft draft) =>
      _api.createTravelAdvance(draft);

  @override
  Future<ExpenseRecord> updateRecord(
    int documentId,
    ExpenseUpdateDraft draft,
  ) => _api.updateRecord(documentId, draft);

  @override
  Future<ExpensePeriod> requestAdvanceCorrection(
    int periodId,
    String observation,
  ) => _api.requestAdvanceCorrection(periodId, observation);

  @override
  Future<ExpensePeriod> confirmReceipt(
    int periodId,
    ExpenseReceiptDraft draft,
  ) => _api.confirmReceipt(periodId, draft);
}

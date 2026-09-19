import 'package:dio/dio.dart';

import '../../../core/network/api_response.dart';
import '../domain/expense_models.dart';

class ExpensesApi {
  const ExpensesApi(this._dio);
  final Dio _dio;

  Future<ExpenseDashboard> dashboard() async => ExpenseDashboard.fromJson(
    apiData(await _dio.get<dynamic>('my-expenses/dashboard')),
  );

  Future<ExpenseRubrics> rubrics() async => ExpenseRubrics.fromJson(
    apiData(await _dio.get<dynamic>('my-expenses/rubrics')),
  );

  Future<ExpenseRecord> record(int documentId) async => ExpenseRecord.fromJson(
    apiData(await _dio.get<dynamic>('my-expenses/records/$documentId')),
  );

  Future<ExpenseFile> file(int documentId) async {
    final response = await _dio.get<List<int>>(
      'my-expenses/records/$documentId/file',
      options: Options(responseType: ResponseType.bytes),
    );
    ensureApiSuccess(response);
    return ExpenseFile(
      bytes: response.data ?? const [],
      contentType:
          response.headers.value(Headers.contentTypeHeader) ??
          'application/octet-stream',
    );
  }

  Future<ExpenseRecord> resubmit(int documentId) async =>
      ExpenseRecord.fromJson(
        apiData(
          await _dio.post<dynamic>('my-expenses/records/$documentId/resubmit'),
        ),
      );

  Future<ExpenseRecord> validateFuel(int documentId) async =>
      ExpenseRecord.fromJson(
        apiData(
          await _dio.post<dynamic>(
            'my-expenses/records/$documentId/fuel-evidence/validate',
          ),
        ),
      );

  Future<ExpenseRecord> saveFuelStatement(
    int documentId,
    String statement,
  ) async => ExpenseRecord.fromJson(
    apiData(
      await _dio.post<dynamic>(
        'my-expenses/records/$documentId/fuel-evidence/statement',
        data: {'statement': statement},
        options: Options(contentType: Headers.jsonContentType),
      ),
    ),
  );

  Future<ExpensePeriod> submitPeriod(int periodId) async =>
      ExpensePeriod.fromJson(
        apiData(
          await _dio.post<dynamic>('my-expenses/periods/$periodId/submit'),
        ),
      );

  Future<ExpenseRecord> upload(ExpenseUploadDraft draft) async {
    final file = draft.filePath != null
        ? await MultipartFile.fromFile(
            draft.filePath!,
            filename: draft.fileName,
          )
        : MultipartFile.fromBytes(draft.fileBytes!, filename: draft.fileName);
    final response = await _dio.post<dynamic>(
      'my-expenses/records',
      data: FormData.fromMap({
        'section': draft.section,
        'expense_date': _date(draft.expenseDate),
        'amount': draft.amount.toStringAsFixed(2),
        'currency': 'ARS',
        'rubric': draft.rubric,
        'merchant_name': draft.merchantName ?? '',
        'description': draft.description ?? '',
        'fiscal_kind': 'unknown',
        'personal_expense_period_id': draft.periodId?.toString() ?? '',
        'file': file,
      }),
      options: Options(headers: {'Idempotency-Key': draft.idempotencyKey}),
    );
    return ExpenseRecord.fromJson(apiData(response));
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

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

  Future<ExpenseFile> report({
    required int periodId,
    String recordType = 'all',
  }) async {
    final response = await _dio.get<List<int>>(
      'my-expenses/report.pdf',
      queryParameters: {
        'scope': 'period',
        'period_id': periodId,
        'record_type': recordType,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    ensureApiSuccess(response);
    return ExpenseFile(
      bytes: response.data ?? const [],
      contentType:
          response.headers.value(Headers.contentTypeHeader) ??
          'application/pdf',
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

  Future<ExpensePeriod> createTravelAdvance(TravelAdvanceDraft draft) async =>
      ExpensePeriod.fromJson(
        apiData(
          await _dio.post<dynamic>(
            'my-expenses/travel-advances',
            data: {
              'label': draft.label,
              'funding_mode': draft.fundingMode,
              'currency': 'ARS',
              'amount': draft.amount,
              'received_at': _date(draft.receivedAt),
              'coverage_start': _date(draft.coverageStart),
              'coverage_end': _date(draft.coverageEnd),
              'received_method': draft.receivedMethod,
              'bank_reference': draft.bankReference,
            },
          ),
        ),
      );

  Future<ExpenseRecord> updateRecord(
    int documentId,
    ExpenseUpdateDraft draft,
  ) async => ExpenseRecord.fromJson(
    apiData(
      await _dio.patch<dynamic>(
        'my-expenses/records/$documentId',
        data: {
          'expense_date': _date(draft.expenseDate),
          'amount': draft.amount,
          'currency': 'ARS',
          'rubric': draft.rubric,
          'period_id': draft.periodId,
          'merchant_name': draft.merchantName,
          'receipt_reference': draft.receiptReference,
          'description': draft.description,
          'fiscal_kind': 'unknown',
          'travel_purpose': draft.travelPurpose,
          'benefit_name': draft.benefitName,
          'fuel_ticket_time': draft.fuelTicketTime,
          'fuel_vehicle_plate': draft.fuelVehiclePlate,
          'fuel_province': draft.fuelProvince,
          'fuel_city': draft.fuelCity,
        },
      ),
    ),
  );

  Future<ExpensePeriod> requestAdvanceCorrection(
    int periodId,
    String observation,
  ) async => ExpensePeriod.fromJson(
    apiData(
      await _dio.post<dynamic>(
        'my-expenses/periods/$periodId/advance-correction-request',
        data: {'observation': observation},
      ),
    ),
  );

  Future<ExpensePeriod> confirmReceipt(
    int periodId,
    ExpenseReceiptDraft draft,
  ) async => ExpensePeriod.fromJson(
    apiData(
      await _dio.post<dynamic>(
        'my-expenses/periods/$periodId/receipt-confirmation',
        data: {
          'received_amount': draft.amount,
          'received_at': _date(draft.receivedAt),
          'received_method': draft.method,
          'bank_reference': draft.bankReference,
        },
      ),
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
        'receipt_reference': draft.receiptReference ?? '',
        'description': draft.description ?? '',
        'fiscal_kind': 'unknown',
        'travel_purpose': draft.travelPurpose ?? '',
        'benefit_name': draft.benefitName ?? '',
        'fuel_ticket_time': draft.fuelTicketTime ?? '',
        'fuel_vehicle_plate': draft.fuelVehiclePlate ?? '',
        'fuel_province': draft.fuelProvince ?? '',
        'fuel_city': draft.fuelCity ?? '',
        'personal_expense_period_id': draft.periodId?.toString() ?? '',
        'geosat_reservation_id': draft.geosatReservationId?.toString() ?? '',
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

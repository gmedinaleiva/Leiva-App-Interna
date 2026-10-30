import 'package:dio/dio.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/api_error.dart';
import '../domain/expense_models.dart';

class ExpensesApi {
  const ExpensesApi(this._dio);
  final Dio _dio;

  Future<List<GeographicOption>> provinces() => _geography('provinces');
  Future<List<GeographicOption>> localities(int provinceId) =>
      _geography('localities', {'province_id': provinceId});
  Future<List<GeographicOption>> _geography(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    final data = apiData(
      await _dio.get<dynamic>(
        'my-expenses/geography/$path',
        queryParameters: query,
      ),
    );
    return (data['items'] as List)
        .map(
          (row) =>
              GeographicOption.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

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

  Future<ExpenseRecord> cancelRecord(int documentId, String reason) async =>
      ExpenseRecord.fromJson(
        apiData(
          await _dio.post<dynamic>(
            'my-expenses/records/$documentId/cancel',
            data: {'statement': reason},
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
          'funding_intent': draft.fundingIntent,
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
    // Camera/content URI and browser blob paths are not local filesystem paths.
    // Use the bytes already read by the picker on every platform.
    final MultipartFile file;
    if (draft.fileBytes != null && draft.fileBytes!.isNotEmpty) {
      file = MultipartFile.fromBytes(
        draft.fileBytes!,
        filename: draft.fileName,
      );
    } else if (draft.filePath != null && draft.filePath!.isNotEmpty) {
      file = await MultipartFile.fromFile(
        draft.filePath!,
        filename: draft.fileName,
      );
    } else {
      throw const ApiFailure(
        statusCode: 0,
        code: 'attachment_unreadable',
        message: 'No se pudo leer la foto. Volvé a seleccionarla.',
      );
    }
    final fields = <String, dynamic>{
      'section': draft.section,
      'expense_date': _date(draft.expenseDate),
      'amount': draft.amount.toStringAsFixed(2),
      'currency': draft.currency,
      'rubric': draft.rubric,
      'merchant_name': draft.merchantName ?? '',
      'receipt_reference': draft.receiptReference ?? '',
      'description': draft.description ?? '',
      'fiscal_kind': draft.fiscalKind,
      'travel_purpose': draft.travelPurpose ?? '',
      'benefit_name': draft.benefitName ?? '',
      'benefit_period': draft.benefitPeriod ?? '',
      'fuel_ticket_time': draft.fuelTicketTime ?? '',
      'fuel_vehicle_plate': draft.fuelVehiclePlate ?? '',
      'fuel_province': draft.fuelProvince ?? '',
      'fuel_city': draft.fuelCity ?? '',
      'personal_expense_period_id': draft.periodId?.toString() ?? '',
      'geosat_reservation_id': draft.geosatReservationId?.toString() ?? '',
      'petty_cash_fund_id': draft.pettyCashFundId?.toString() ?? '',
      'file': file,
    };
    if (draft.fundingIntent != null) {
      fields['funding_intent'] = draft.fundingIntent;
    }
    final response = await _dio.post<dynamic>(
      'my-expenses/records',
      data: FormData.fromMap(fields),
      options: Options(headers: {'Idempotency-Key': draft.idempotencyKey}),
    );
    return ExpenseRecord.fromJson(apiData(response));
  }

  Future<List<PettyCashFund>> pettyCashFunds() async {
    final data = apiData(
      await _dio.get<dynamic>('my-expenses/petty-cash-funds'),
    );
    final items = data['items'];
    if (items is! List) {
      throw const FormatException('La API devolvió fondos inesperados.');
    }
    return items
        .cast<Map<String, dynamic>>()
        .map(PettyCashFund.fromJson)
        .toList();
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

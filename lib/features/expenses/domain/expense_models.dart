class ExpensePeriod {
  const ExpensePeriod({
    required this.id,
    required this.status,
    required this.statusCode,
    required this.label,
    required this.currency,
    required this.documentCount,
    required this.circuit,
    this.advanceAmount,
    this.consumedAmount,
    this.availableAmount,
    this.fundingMode,
    this.coverageStart,
    this.coverageEnd,
    this.receivedAt,
  });

  factory ExpensePeriod.fromJson(Map<String, dynamic> json) => ExpensePeriod(
    id: json['id'] as int,
    status: json['status_label'] as String? ?? json['status'] as String,
    statusCode: json['status'] as String,
    label: json['label'] as String? ?? 'Rendición',
    currency: json['currency'] as String? ?? 'ARS',
    documentCount: json['document_count'] as int? ?? 0,
    circuit: json['circuit'] as String? ?? 'employee_benefit',
    advanceAmount: (json['advance_amount'] as num?)?.toDouble(),
    consumedAmount: (json['consumed_amount'] as num?)?.toDouble(),
    availableAmount: (json['available_amount'] as num?)?.toDouble(),
    fundingMode: json['funding_mode'] as String?,
    coverageStart: DateTime.tryParse(json['coverage_start'] as String? ?? ''),
    coverageEnd: DateTime.tryParse(json['coverage_end'] as String? ?? ''),
    receivedAt: DateTime.tryParse(json['received_at'] as String? ?? ''),
  );

  final int id;
  final String status;
  final String statusCode;
  final String label;
  final String currency;
  final int documentCount;
  final String circuit;
  final double? advanceAmount;
  final double? consumedAmount;
  final double? availableAmount;
  final String? fundingMode;
  final DateTime? coverageStart;
  final DateTime? coverageEnd;
  final DateTime? receivedAt;
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.currency,
    required this.hasFile,
    this.date,
    this.amount,
    this.merchant,
    this.rubric,
    this.reviewReason,
    this.periodId,
    this.fuelEvidence,
    this.description,
    this.reference,
    this.travelPurpose,
    this.benefitName,
    this.geosatReservationId,
  });

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) => ExpenseRecord(
    id: json['id'] as int,
    type: json['type'] as String,
    status: json['status'] as String,
    title: json['title'] as String? ?? 'Comprobante',
    currency: json['currency'] as String? ?? 'ARS',
    hasFile: json['has_file'] as bool? ?? false,
    date: json['date'] == null
        ? null
        : DateTime.tryParse(json['date'] as String),
    amount: (json['amount'] as num?)?.toDouble(),
    merchant: json['merchant'] as String?,
    rubric: json['rubric'] as String?,
    reviewReason: json['review_reason'] as String?,
    periodId: json['period_id'] as int?,
    fuelEvidence: json['fuel_evidence'] as Map<String, dynamic>?,
    description: json['description'] as String?,
    reference: json['reference'] as String?,
    travelPurpose: json['trip'] as String?,
    benefitName: json['benefit_name'] as String?,
    geosatReservationId: json['geosat_reservation_id'] as int?,
  );

  final int id;
  final String type;
  final String status;
  final String title;
  final String currency;
  final bool hasFile;
  final DateTime? date;
  final double? amount;
  final String? merchant;
  final String? rubric;
  final String? reviewReason;
  final int? periodId;
  final Map<String, dynamic>? fuelEvidence;
  final String? description;
  final String? reference;
  final String? travelPurpose;
  final String? benefitName;
  final int? geosatReservationId;
}

class ExpenseFile {
  const ExpenseFile({required this.bytes, required this.contentType});
  final List<int> bytes;
  final String contentType;
  bool get isImage => contentType.startsWith('image/');
  bool get isPdf => contentType == 'application/pdf';
}

class ExpenseDashboard {
  const ExpenseDashboard({
    required this.capabilities,
    required this.periods,
    required this.records,
    required this.alerts,
    required this.fines,
  });

  factory ExpenseDashboard.fromJson(Map<String, dynamic> json) =>
      ExpenseDashboard(
        capabilities: Map<String, dynamic>.unmodifiable(
          json['capabilities'] as Map<String, dynamic>? ?? const {},
        ),
        periods: _maps(json['periods']).map(ExpensePeriod.fromJson).toList(),
        records: _maps(json['records']).map(ExpenseRecord.fromJson).toList(),
        alerts: _maps(json['alerts']),
        fines: _maps(json['fines']).map(ExpenseFine.fromJson).toList(),
      );

  final Map<String, dynamic> capabilities;
  final List<ExpensePeriod> periods;
  final List<ExpenseRecord> records;
  final List<Map<String, dynamic>> alerts;
  final List<ExpenseFine> fines;

  bool allows(String key) => capabilities[key] == true;
}

class ExpenseFine {
  const ExpenseFine({
    required this.id,
    required this.status,
    this.reason,
    this.infractionAt,
    this.dueDate,
    this.amount,
    this.currency,
    this.vehicleLabel,
    this.employeeManagement = const {},
  });

  factory ExpenseFine.fromJson(Map<String, dynamic> json) => ExpenseFine(
    id: json['id'] as int,
    status: json['status'] as String,
    reason: json['reason'] as String?,
    infractionAt: json['infraction_at'] == null
        ? null
        : DateTime.tryParse(json['infraction_at'] as String)?.toLocal(),
    dueDate: json['due_date'] == null
        ? null
        : DateTime.tryParse(json['due_date'] as String),
    amount: (json['amount'] as num?)?.toDouble(),
    currency: json['currency'] as String?,
    vehicleLabel: json['vehicle_label'] as String?,
    employeeManagement: Map<String, dynamic>.unmodifiable(
      json['employee_management'] as Map<String, dynamic>? ?? const {},
    ),
  );

  final int id;
  final String status;
  final String? reason;
  final DateTime? infractionAt;
  final DateTime? dueDate;
  final double? amount;
  final String? currency;
  final String? vehicleLabel;
  final Map<String, dynamic> employeeManagement;
}

class ExpenseRubrics {
  const ExpenseRubrics({required this.travel, required this.benefits});

  factory ExpenseRubrics.fromJson(Map<String, dynamic> json) => ExpenseRubrics(
    travel: (json['travel'] as List? ?? const []).cast<String>(),
    benefits: (json['benefits'] as List? ?? const []).cast<String>(),
  );

  final List<String> travel;
  final List<String> benefits;
}

class ExpenseUploadDraft {
  const ExpenseUploadDraft({
    required this.idempotencyKey,
    required this.section,
    required this.expenseDate,
    required this.amount,
    required this.rubric,
    required this.fileName,
    this.filePath,
    this.fileBytes,
    this.periodId,
    this.merchantName,
    this.receiptReference,
    this.description,
    this.travelPurpose,
    this.benefitName,
    this.fuelTicketTime,
    this.fuelVehiclePlate,
    this.fuelProvince,
    this.fuelCity,
    this.geosatReservationId,
  });

  final String idempotencyKey;
  final String section;
  final DateTime expenseDate;
  final double amount;
  final String rubric;
  final String fileName;
  final String? filePath;
  final List<int>? fileBytes;
  final int? periodId;
  final String? merchantName;
  final String? receiptReference;
  final String? description;
  final String? travelPurpose;
  final String? benefitName;
  final String? fuelTicketTime;
  final String? fuelVehiclePlate;
  final String? fuelProvince;
  final String? fuelCity;
  final int? geosatReservationId;
}

class TravelAdvanceDraft {
  const TravelAdvanceDraft({
    required this.label,
    required this.fundingMode,
    required this.amount,
    required this.receivedAt,
    required this.coverageStart,
    required this.coverageEnd,
    required this.receivedMethod,
    this.bankReference,
  });

  final String label;
  final String fundingMode;
  final double amount;
  final DateTime receivedAt;
  final DateTime coverageStart;
  final DateTime coverageEnd;
  final String receivedMethod;
  final String? bankReference;
}

class ExpenseUpdateDraft {
  const ExpenseUpdateDraft({
    required this.expenseDate,
    required this.amount,
    required this.rubric,
    required this.periodId,
    this.merchantName,
    this.receiptReference,
    this.description,
    this.travelPurpose,
    this.benefitName,
    this.fuelTicketTime,
    this.fuelVehiclePlate,
    this.fuelProvince,
    this.fuelCity,
  });

  final DateTime expenseDate;
  final double amount;
  final String rubric;
  final int periodId;
  final String? merchantName;
  final String? receiptReference;
  final String? description;
  final String? travelPurpose;
  final String? benefitName;
  final String? fuelTicketTime;
  final String? fuelVehiclePlate;
  final String? fuelProvince;
  final String? fuelCity;
}

class ExpenseReceiptDraft {
  const ExpenseReceiptDraft({
    required this.amount,
    required this.receivedAt,
    required this.method,
    this.bankReference,
  });

  final double amount;
  final DateTime receivedAt;
  final String method;
  final String? bankReference;
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const [];
  return value.cast<Map<String, dynamic>>();
}

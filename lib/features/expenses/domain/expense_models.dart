class ExpensePeriod {
  const ExpensePeriod({
    required this.id,
    required this.status,
    required this.label,
    required this.currency,
    required this.documentCount,
    this.advanceAmount,
    this.consumedAmount,
    this.availableAmount,
  });

  factory ExpensePeriod.fromJson(Map<String, dynamic> json) => ExpensePeriod(
    id: json['id'] as int,
    status: json['status_label'] as String? ?? json['status'] as String,
    label: json['label'] as String? ?? 'Rendición',
    currency: json['currency'] as String? ?? 'ARS',
    documentCount: json['document_count'] as int? ?? 0,
    advanceAmount: (json['advance_amount'] as num?)?.toDouble(),
    consumedAmount: (json['consumed_amount'] as num?)?.toDouble(),
    availableAmount: (json['available_amount'] as num?)?.toDouble(),
  );

  final int id;
  final String status;
  final String label;
  final String currency;
  final int documentCount;
  final double? advanceAmount;
  final double? consumedAmount;
  final double? availableAmount;
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
}

class ExpenseDashboard {
  const ExpenseDashboard({
    required this.capabilities,
    required this.periods,
    required this.records,
    required this.alerts,
  });

  factory ExpenseDashboard.fromJson(Map<String, dynamic> json) =>
      ExpenseDashboard(
        capabilities: Map<String, dynamic>.unmodifiable(
          json['capabilities'] as Map<String, dynamic>? ?? const {},
        ),
        periods: _maps(json['periods']).map(ExpensePeriod.fromJson).toList(),
        records: _maps(json['records']).map(ExpenseRecord.fromJson).toList(),
        alerts: _maps(json['alerts']),
      );

  final Map<String, dynamic> capabilities;
  final List<ExpensePeriod> periods;
  final List<ExpenseRecord> records;
  final List<Map<String, dynamic>> alerts;

  bool allows(String key) => capabilities[key] == true;
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
    this.description,
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
  final String? description;
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const [];
  return value.cast<Map<String, dynamic>>();
}

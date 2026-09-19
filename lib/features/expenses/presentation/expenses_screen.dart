import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../core/security/idempotency_key.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_models.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    required this.gateway,
    required this.canUpload,
    super.key,
  });
  final ExpensesGateway gateway;
  final bool canUpload;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _loading = true;
  String? _error;
  ExpenseDashboard? _dashboard;
  ExpenseRubrics? _rubrics;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<dynamic>([
        widget.gateway.dashboard(),
        widget.gateway.rubrics(),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = result[0] as ExpenseDashboard;
        _rubrics = result[1] as ExpenseRubrics;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _expenseMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _upload() async {
    if (_dashboard == null || _rubrics == null) return;
    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreateExpenseScreen(
          gateway: widget.gateway,
          dashboard: _dashboard!,
          rubrics: _rubrics!,
        ),
      ),
    );
    if (uploaded == true) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis gastos'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    floatingActionButton: widget.canUpload && _dashboard != null
        ? FloatingActionButton.extended(
            key: const Key('createExpenseButton'),
            onPressed: _upload,
            backgroundColor: const Color(0xFFEA580C),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Cargar comprobante'),
          )
        : null,
    body: RefreshIndicator(onRefresh: _load, child: _body()),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ExpenseMessage(message: _error!, onRetry: _load);
    }
    final data = _dashboard!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      children: [
        if (data.alerts.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFEC84B)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFB54708),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${data.alerts.length} aviso${data.alerts.length == 1 ? '' : 's'} requiere${data.alerts.length == 1 ? '' : 'n'} tu atención.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        const _ExpenseTitle('Rendiciones'),
        const SizedBox(height: 10),
        if (data.periods.isEmpty)
          const _SmallEmpty('No tenés rendiciones registradas.')
        else
          ...data.periods.map(
            (period) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PeriodCard(period),
            ),
          ),
        const SizedBox(height: 18),
        const _ExpenseTitle('Comprobantes'),
        const SizedBox(height: 10),
        if (data.records.isEmpty)
          const _SmallEmpty('No tenés comprobantes cargados.')
        else
          ...data.records.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecordCard(record),
            ),
          ),
      ],
    );
  }
}

class CreateExpenseScreen extends StatefulWidget {
  const CreateExpenseScreen({
    required this.gateway,
    required this.dashboard,
    required this.rubrics,
    super.key,
  });
  final ExpensesGateway gateway;
  final ExpenseDashboard dashboard;
  final ExpenseRubrics rubrics;

  @override
  State<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends State<CreateExpenseScreen> {
  final _idempotencyKey = newIdempotencyKey();
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _description = TextEditingController();
  late String _section;
  late DateTime _date;
  String? _rubric;
  int? _periodId;
  PlatformFile? _file;
  bool _saving = false;
  String? _error;

  bool get _travelAllowed => widget.dashboard.allows('travel');
  List<String> get _currentRubrics =>
      _section == 'travel' ? widget.rubrics.travel : widget.rubrics.benefits;

  @override
  void initState() {
    super.initState();
    _section = _travelAllowed ? 'travel' : 'benefits';
    _date = DateTime.now();
    _rubric = _currentRubrics.firstOrNull;
    _periodId = widget.dashboard.periods.firstOrNull?.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _description.dispose();
    super.dispose();
  }

  void _changeSection(String value) {
    setState(() {
      _section = value;
      _rubric = _currentRubrics.firstOrNull;
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _pickFile() async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (selected == null) return;
    final length = selected.lengthSync() ?? await selected.length();
    if (length != null && length > 15 * 1024 * 1024) {
      setState(
        () => _error = 'El archivo supera el límite de 15 MB de la app.',
      );
      return;
    }
    setState(() {
      _file = selected;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_file == null) {
      setState(() => _error = 'Seleccioná un comprobante.');
      return;
    }
    if (_section == 'travel' && _periodId == null) {
      setState(() => _error = 'Seleccioná una rendición para el viático.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.upload(
        ExpenseUploadDraft(
          idempotencyKey: _idempotencyKey,
          section: _section,
          expenseDate: _date,
          amount: double.parse(_amount.text.replaceAll(',', '.')),
          rubric: _rubric!,
          fileName: _file!.name,
          filePath: _file!.path,
          fileBytes: await _file!.readAsBytes(),
          periodId: _section == 'travel' ? _periodId : null,
          merchantName: _expenseNullable(_merchant.text),
          description: _expenseNullable(_description.text),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _expenseMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Cargar comprobante'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_travelAllowed)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'travel',
                  label: Text('Viático'),
                  icon: Icon(Icons.luggage_outlined),
                ),
                ButtonSegment(
                  value: 'benefits',
                  label: Text('Beneficio'),
                  icon: Icon(Icons.card_giftcard_outlined),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (value) => _changeSection(value.first),
            ),
          if (_travelAllowed) const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha del gasto',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(_expenseDate(_date)),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Importe',
              prefixText: r'$ ',
            ),
            validator: (value) =>
                (double.tryParse((value ?? '').replaceAll(',', '.')) ?? 0) <= 0
                ? 'Ingresá un importe válido'
                : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _rubric,
            decoration: const InputDecoration(labelText: 'Rubro'),
            items: _currentRubrics
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _rubric = value),
            validator: (value) => value == null ? 'Seleccioná un rubro' : null,
          ),
          if (_section == 'travel') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _periodId,
              decoration: const InputDecoration(labelText: 'Rendición'),
              items: widget.dashboard.periods
                  .map(
                    (period) => DropdownMenuItem(
                      value: period.id,
                      child: Text(period.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _periodId = value),
              validator: (value) =>
                  value == null ? 'Seleccioná una rendición' : null,
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _merchant,
            maxLength: 220,
            decoration: const InputDecoration(labelText: 'Comercio (opcional)'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _description,
            maxLines: 3,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickFile,
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(_file?.name ?? 'Seleccionar comprobante PDF o imagen'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB42318)),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_saving ? 'Enviando...' : 'Enviar comprobante'),
          ),
        ],
      ),
    ),
  );
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard(this.period);
  final ExpensePeriod period;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _expenseBox(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                period.label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              period.status,
              style: const TextStyle(
                color: Color(0xFFEA580C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${period.documentCount} comprobantes · Consumido ${_money(period.consumedAmount, period.currency)}',
          style: const TextStyle(color: Color(0xFF667085)),
        ),
        if (period.availableAmount != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Disponible ${_money(period.availableAmount, period.currency)}',
              style: const TextStyle(
                color: Color(0xFF067647),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    ),
  );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard(this.record);
  final ExpenseRecord record;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _expenseBox(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                record.merchant ?? record.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              _money(record.amount, record.currency),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          [
            record.rubric,
            record.date == null ? null : _expenseDate(record.date!),
          ].whereType<String>().join(' · '),
          style: const TextStyle(color: Color(0xFF667085)),
        ),
        const SizedBox(height: 7),
        Text(
          record.status,
          style: const TextStyle(
            color: Color(0xFFEA580C),
            fontWeight: FontWeight.w700,
          ),
        ),
        if (record.reviewReason?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              record.reviewReason!,
              style: const TextStyle(color: Color(0xFFB42318)),
            ),
          ),
      ],
    ),
  );
}

class _ExpenseTitle extends StatelessWidget {
  const _ExpenseTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
  );
}

class _SmallEmpty extends StatelessWidget {
  const _SmallEmpty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _expenseBox(),
    child: Text(text, style: const TextStyle(color: Color(0xFF667085))),
  );
}

class _ExpenseMessage extends StatelessWidget {
  const _ExpenseMessage({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: _expenseBox(),
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 42,
              color: Color(0xFFEA580C),
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    ],
  );
}

BoxDecoration _expenseBox() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: const Color(0xFFE3E8EF)),
);
String _expenseMessage(Object error) {
  if (error is ApiFailure) return error.message;
  if (error is DioException) return 'No pudimos comunicarnos con el portal.';
  return 'No pudimos completar la operación.';
}

String? _expenseNullable(String value) =>
    value.trim().isEmpty ? null : value.trim();
String _expenseDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _money(double? value, String currency) =>
    value == null ? '—' : '$currency ${value.toStringAsFixed(2)}';

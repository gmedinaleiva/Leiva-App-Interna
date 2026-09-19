import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_error.dart';
import '../../../core/security/idempotency_key.dart';
import '../../vehicles/data/vehicles_repository.dart';
import '../../vehicles/domain/vehicle_models.dart';
import '../../vehicles/presentation/vehicles_screen.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_models.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    required this.gateway,
    required this.canUpload,
    this.vehiclesGateway,
    super.key,
  });
  final ExpensesGateway gateway;
  final bool canUpload;
  final VehiclesGateway? vehiclesGateway;

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
    var trips = const <VehicleReservation>[];
    if (widget.vehiclesGateway != null) {
      try {
        trips = await widget.vehiclesGateway!.reservations();
      } catch (_) {
        // El comprobante puede cargarse sin vincular un viaje.
      }
    }
    if (!mounted) return;
    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreateExpenseScreen(
          gateway: widget.gateway,
          dashboard: _dashboard!,
          rubrics: _rubrics!,
          vehicleReservations: trips,
        ),
      ),
    );
    if (uploaded == true) await _load();
  }

  Future<void> _openReport() async {
    final dashboard = _dashboard;
    if (dashboard == null || dashboard.periods.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ExpenseReportScreen(
          gateway: widget.gateway,
          periods: dashboard.periods,
        ),
      ),
    );
  }

  Future<void> _openFine(ExpenseFine fine) async {
    final gateway = widget.vehiclesGateway;
    if (gateway == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            VehicleNoticeDetailScreen(gateway: gateway, noticeId: fine.id),
      ),
    );
  }

  Future<void> _createAdvance() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TravelAdvanceScreen(gateway: widget.gateway),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _submitPeriod(ExpensePeriod period) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar rendición'),
        content: Text(
          'Se enviará “${period.label}” a Gerencia. Los comprobantes deben tener sus controles terminados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runPeriodAction(() => widget.gateway.submitPeriod(period.id));
  }

  Future<void> _requestCorrection(ExpensePeriod period) async {
    final observation = await _textDialog(
      context,
      title: 'Solicitar corrección',
      label: 'Motivo para Gerencia',
    );
    if (observation == null) return;
    await _runPeriodAction(
      () => widget.gateway.requestAdvanceCorrection(period.id, observation),
    );
  }

  Future<void> _confirmReceipt(ExpensePeriod period) async {
    final draft = await showDialog<ExpenseReceiptDraft>(
      context: context,
      builder: (_) => const _ReceiptDialog(),
    );
    if (draft == null) return;
    await _runPeriodAction(
      () => widget.gateway.confirmReceipt(period.id, draft),
    );
  }

  Future<void> _runPeriodAction(
    Future<ExpensePeriod> Function() operation,
  ) async {
    try {
      await operation();
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_expenseMessage(error))));
    }
  }

  Future<void> _openRecord(ExpenseRecord record) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ExpenseRecordScreen(gateway: widget.gateway, documentId: record.id),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis gastos'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      actions: [
        if (_dashboard?.periods.isNotEmpty == true)
          IconButton(
            tooltip: 'Planilla PDF',
            onPressed: _loading ? null : _openReport,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        if (_dashboard?.allows('advances') == true)
          IconButton(
            tooltip: 'Registrar adelanto',
            onPressed: _loading ? null : _createAdvance,
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
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
              child: _PeriodCard(
                period,
                onSubmit:
                    period.statusCode == 'open' ||
                        period.statusCode == 'observed'
                    ? () => _submitPeriod(period)
                    : null,
                onCorrection:
                    data.allows('advances') &&
                        (period.fundingMode == 'advance' ||
                            period.fundingMode == 'allowance') &&
                        (period.statusCode == 'open' ||
                            period.statusCode == 'observed')
                    ? () => _requestCorrection(period)
                    : null,
                onReceipt: period.statusCode == 'approved'
                    ? () => _confirmReceipt(period)
                    : null,
              ),
            ),
          ),
        const SizedBox(height: 18),
        if (data.fines.isNotEmpty) ...[
          const _ExpenseTitle('Multas personales'),
          const SizedBox(height: 10),
          ...data.fines.map(
            (fine) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE3E8EF)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: Text(fine.reason ?? 'Multa o aviso'),
                subtitle: Text(
                  [
                    fine.vehicleLabel,
                    fine.infractionAt == null
                        ? null
                        : _expenseDate(fine.infractionAt!),
                    fine.status,
                  ].whereType<String>().join(' · '),
                ),
                trailing: widget.vehiclesGateway == null
                    ? null
                    : const Icon(Icons.chevron_right_rounded),
                onTap: widget.vehiclesGateway == null
                    ? null
                    : () => _openFine(fine),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        const _ExpenseTitle('Comprobantes'),
        const SizedBox(height: 10),
        if (data.records.isEmpty)
          const _SmallEmpty('No tenés comprobantes cargados.')
        else
          ...data.records.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecordCard(record, onTap: () => _openRecord(record)),
            ),
          ),
      ],
    );
  }
}

class ExpenseReportScreen extends StatefulWidget {
  const ExpenseReportScreen({
    required this.gateway,
    required this.periods,
    super.key,
  });

  final ExpensesGateway gateway;
  final List<ExpensePeriod> periods;

  @override
  State<ExpenseReportScreen> createState() => _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends State<ExpenseReportScreen> {
  late int _periodId;
  String _recordType = 'all';
  ExpenseFile? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _periodId = widget.periods.first.id;
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final report = await widget.gateway.report(
        periodId: _periodId,
        recordType: _recordType,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _expenseMessage(error);
      });
    }
  }

  Future<void> _share() async {
    final report = _report;
    if (report == null) return;
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Planilla de Mis Gastos',
        files: [
          XFile.fromData(
            Uint8List.fromList(report.bytes),
            mimeType: 'application/pdf',
          ),
        ],
        fileNameOverrides: ['mis-gastos-periodo-$_periodId.pdf'],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Planilla de Mis Gastos'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      actions: [
        if (_report != null)
          IconButton(
            tooltip: 'Compartir PDF',
            onPressed: _share,
            icon: const Icon(Icons.share_outlined),
          ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DropdownButtonFormField<int>(
          initialValue: _periodId,
          decoration: const InputDecoration(labelText: 'Rendición'),
          items: widget.periods
              .map(
                (period) => DropdownMenuItem(
                  value: period.id,
                  child: Text(period.label),
                ),
              )
              .toList(),
          onChanged: _loading
              ? null
              : (value) {
                  if (value != null) setState(() => _periodId = value);
                },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _recordType,
          decoration: const InputDecoration(labelText: 'Contenido'),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Todos los gastos')),
            DropdownMenuItem(value: 'travel', child: Text('Viáticos')),
            DropdownMenuItem(value: 'benefits', child: Text('Beneficios')),
          ],
          onChanged: _loading
              ? null
              : (value) {
                  if (value != null) setState(() => _recordType = value);
                },
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _generate,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(_loading ? 'Generando...' : 'Generar planilla'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
        ],
        if (_report != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.share_outlined),
            label: const Text('Compartir o guardar PDF'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 620,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PdfViewer.data(
                Uint8List.fromList(_report!.bytes),
                sourceName: 'mis-gastos-periodo-$_periodId.pdf',
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class ExpenseRecordScreen extends StatefulWidget {
  const ExpenseRecordScreen({
    required this.gateway,
    required this.documentId,
    super.key,
  });
  final ExpensesGateway gateway;
  final int documentId;

  @override
  State<ExpenseRecordScreen> createState() => _ExpenseRecordScreenState();
}

class _ExpenseRecordScreenState extends State<ExpenseRecordScreen> {
  ExpenseRecord? _record;
  ExpenseFile? _file;
  String? _error;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final record = await widget.gateway.record(widget.documentId);
      if (!mounted) return;
      setState(() {
        _record = record;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _expenseMessage(error));
    }
  }

  Future<void> _preview() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final file = await widget.gateway.file(widget.documentId);
      if (!mounted) return;
      setState(() {
        _file = file;
        _working = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = _expenseMessage(error);
      });
    }
  }

  Future<void> _resubmit() async {
    setState(() => _working = true);
    try {
      await widget.gateway.resubmit(widget.documentId);
      if (!mounted) return;
      setState(() => _working = false);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comprobante reenviado.')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = _expenseMessage(error);
      });
    }
  }

  Future<void> _validateFuel() async {
    setState(() => _working = true);
    try {
      await widget.gateway.validateFuel(widget.documentId);
      if (!mounted) return;
      setState(() => _working = false);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = _expenseMessage(error);
      });
    }
  }

  Future<void> _statement() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descargo de combustible'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Descargo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim().length >= 8),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      controller.dispose();
      return;
    }
    final value = controller.text.trim();
    controller.dispose();
    setState(() => _working = true);
    try {
      await widget.gateway.saveFuelStatement(widget.documentId, value);
      if (!mounted) return;
      setState(() => _working = false);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = _expenseMessage(error);
      });
    }
  }

  Future<void> _edit() async {
    if (_record == null) return;
    setState(() => _working = true);
    try {
      final values = await Future.wait<dynamic>([
        widget.gateway.dashboard(),
        widget.gateway.rubrics(),
      ]);
      if (!mounted) return;
      setState(() => _working = false);
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => EditExpenseScreen(
            gateway: widget.gateway,
            record: _record!,
            dashboard: values[0] as ExpenseDashboard,
            rubrics: values[1] as ExpenseRubrics,
          ),
        ),
      );
      if (changed == true) await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = _expenseMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalle del comprobante'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    body: _record == null && _error == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_record != null) ...[
                Text(
                  _record!.merchant ?? _record!.title,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _money(_record!.amount, _record!.currency),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${_record!.rubric ?? 'Sin rubro'} · ${_record!.status}'),
                if (_record!.reference?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Referencia: ${_record!.reference}'),
                  ),
                if (_record!.geosatReservationId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Viaje relacionado: #${_record!.geosatReservationId}',
                    ),
                  ),
                if (_record!.reviewReason?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _record!.reviewReason!,
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ),
                const SizedBox(height: 20),
                if (_record!.hasFile)
                  OutlinedButton.icon(
                    onPressed: _working ? null : _preview,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ver comprobante'),
                  ),
                if (_file?.isImage == true) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(Uint8List.fromList(_file!.bytes)),
                  ),
                ] else if (_file?.isPdf == true) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 520,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PdfViewer.data(
                        Uint8List.fromList(_file!.bytes),
                        sourceName: 'comprobante-${widget.documentId}.pdf',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_record!.status == 'personal_expense_draft' ||
                        _record!.status == 'personal_expense_observed')
                      OutlinedButton.icon(
                        onPressed: _working ? null : _edit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar datos'),
                      ),
                    if (_record!.fuelEvidence != null) ...[
                      OutlinedButton.icon(
                        onPressed: _working ? null : _validateFuel,
                        icon: const Icon(Icons.local_gas_station_outlined),
                        label: const Text('Validar combustible'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _working ? null : _statement,
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const Text('Cargar descargo'),
                      ),
                    ],
                    if (_record!.status == 'personal_expense_observed')
                      FilledButton.icon(
                        onPressed: _working ? null : _resubmit,
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Reenviar observado'),
                      ),
                  ],
                ),
              ],
              if (_working)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ),
            ],
          ),
  );
}

class CreateExpenseScreen extends StatefulWidget {
  const CreateExpenseScreen({
    required this.gateway,
    required this.dashboard,
    required this.rubrics,
    required this.vehicleReservations,
    super.key,
  });
  final ExpensesGateway gateway;
  final ExpenseDashboard dashboard;
  final ExpenseRubrics rubrics;
  final List<VehicleReservation> vehicleReservations;

  @override
  State<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends State<CreateExpenseScreen> {
  final _idempotencyKey = newIdempotencyKey();
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _reference = TextEditingController();
  final _description = TextEditingController();
  final _purpose = TextEditingController();
  final _fuelTime = TextEditingController();
  final _fuelPlate = TextEditingController();
  final _fuelProvince = TextEditingController();
  final _fuelCity = TextEditingController();
  late String _section;
  late DateTime _date;
  String? _rubric;
  int? _periodId;
  int? _geosatReservationId;
  PlatformFile? _file;
  bool _saving = false;
  String? _error;

  bool get _travelAllowed => widget.dashboard.allows('travel');
  List<String> get _currentRubrics =>
      _section == 'travel' ? widget.rubrics.travel : widget.rubrics.benefits;
  bool get _isFuel =>
      _section == 'travel' &&
      {'combustible', 'peajes'}.contains(_rubric?.toLowerCase());
  List<ExpensePeriod> get _travelPeriods => widget.dashboard.periods
      .where(
        (item) =>
            item.circuit == 'travel_expense' &&
            {
              'open',
              'observed',
              'partially_observed',
              'partially_approved',
            }.contains(item.statusCode),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _section = _travelAllowed ? 'travel' : 'benefits';
    _date = DateTime.now();
    _rubric = _currentRubrics.firstOrNull;
    _periodId = _travelPeriods.firstOrNull?.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _reference.dispose();
    _description.dispose();
    _purpose.dispose();
    _fuelTime.dispose();
    _fuelPlate.dispose();
    _fuelProvince.dispose();
    _fuelCity.dispose();
    super.dispose();
  }

  void _changeSection(String value) {
    setState(() {
      _section = value;
      _rubric = _currentRubrics.firstOrNull;
      _periodId = value == 'travel' ? _travelPeriods.firstOrNull?.id : null;
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
          receiptReference: _expenseNullable(_reference.text),
          description: _expenseNullable(_description.text),
          travelPurpose: _section == 'travel'
              ? _expenseNullable(_purpose.text)
              : null,
          benefitName: _section == 'benefits'
              ? _expenseNullable(_purpose.text)
              : null,
          fuelTicketTime: _isFuel ? _expenseNullable(_fuelTime.text) : null,
          fuelVehiclePlate: _isFuel ? _expenseNullable(_fuelPlate.text) : null,
          fuelProvince: _isFuel ? _expenseNullable(_fuelProvince.text) : null,
          fuelCity: _isFuel ? _expenseNullable(_fuelCity.text) : null,
          geosatReservationId: _section == 'travel'
              ? _geosatReservationId
              : null,
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
              items: _travelPeriods
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
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _geosatReservationId ?? 0,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Viaje relacionado (opcional)',
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: 0,
                  child: Text('Sin viaje relacionado'),
                ),
                ...widget.vehicleReservations.map(
                  (reservation) => DropdownMenuItem<int>(
                    value: reservation.id,
                    child: Text(
                      '${reservation.destination ?? reservation.purpose ?? 'Viaje'} · ${_expenseDate(reservation.startsAt)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(
                () => _geosatReservationId = value == 0 ? null : value,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _purpose,
            maxLength: 220,
            decoration: InputDecoration(
              labelText: _section == 'travel'
                  ? 'Motivo del viaje (opcional)'
                  : 'Beneficio utilizado',
            ),
            validator: (value) =>
                _section == 'benefits' && (value ?? '').trim().isEmpty
                ? 'Indicá el beneficio utilizado'
                : null,
          ),
          if (_isFuel) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _fuelTime,
              decoration: const InputDecoration(
                labelText: 'Hora del ticket (HH:MM)',
              ),
              validator: (value) =>
                  RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                      .hasMatch((value ?? '').trim())
                  ? null
                  : 'Usá el formato HH:MM',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fuelPlate,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Patente'),
              validator: (value) =>
                  (value ?? '').replaceAll(RegExp('[^A-Za-z0-9]'), '').length <
                      6
                  ? 'Ingresá una patente válida'
                  : null,
            ),
            if (_rubric?.toLowerCase() == 'combustible') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _fuelProvince,
                decoration: const InputDecoration(labelText: 'Provincia'),
                validator: (value) => (value ?? '').trim().length < 2
                    ? 'Ingresá la provincia'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fuelCity,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                validator: (value) => (value ?? '').trim().length < 2
                    ? 'Ingresá la ciudad'
                    : null,
              ),
            ],
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: _merchant,
            maxLength: 220,
            decoration: const InputDecoration(labelText: 'Comercio (opcional)'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _reference,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Referencia del comprobante (opcional)',
            ),
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

class TravelAdvanceScreen extends StatefulWidget {
  const TravelAdvanceScreen({required this.gateway, super.key});
  final ExpensesGateway gateway;

  @override
  State<TravelAdvanceScreen> createState() => _TravelAdvanceScreenState();
}

class _TravelAdvanceScreenState extends State<TravelAdvanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  String _fundingMode = 'advance';
  String _method = 'transfer';
  DateTime _receivedAt = DateTime.now();
  DateTime _coverageStart = DateTime.now();
  DateTime _coverageEnd = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<DateTime?> _date(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 365)),
    lastDate: DateTime.now().add(const Duration(days: 730)),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_coverageEnd.isBefore(_coverageStart) ||
        _receivedAt.isAfter(_coverageEnd)) {
      setState(() => _error = 'Revisá las fechas de acreditación y cobertura.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.createTravelAdvance(
        TravelAdvanceDraft(
          label: _label.text.trim(),
          fundingMode: _fundingMode,
          amount: double.parse(_amount.text.replaceAll(',', '.')),
          receivedAt: _receivedAt,
          coverageStart: _coverageStart,
          coverageEnd: _coverageEnd,
          receivedMethod: _method,
          bankReference: _expenseNullable(_reference.text),
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
    appBar: AppBar(title: const Text('Registrar adelanto')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _label,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _fundingMode,
            decoration: const InputDecoration(labelText: 'Tipo de saldo'),
            items: const [
              DropdownMenuItem(
                value: 'advance',
                child: Text('Adelanto puntual'),
              ),
              DropdownMenuItem(
                value: 'allowance',
                child: Text('Asignación periódica'),
              ),
            ],
            onChanged: (value) => setState(() => _fundingMode = value!),
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
          _DateTile(
            label: 'Fecha de acreditación',
            value: _receivedAt,
            onTap: () async {
              final value = await _date(_receivedAt);
              if (value != null) setState(() => _receivedAt = value);
            },
          ),
          const SizedBox(height: 16),
          _DateTile(
            label: 'Cobertura desde',
            value: _coverageStart,
            onTap: () async {
              final value = await _date(_coverageStart);
              if (value != null) setState(() => _coverageStart = value);
            },
          ),
          const SizedBox(height: 16),
          _DateTile(
            label: 'Cobertura hasta',
            value: _coverageEnd,
            onTap: () async {
              final value = await _date(_coverageEnd);
              if (value != null) setState(() => _coverageEnd = value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Medio recibido'),
            items: const [
              DropdownMenuItem(value: 'transfer', child: Text('Transferencia')),
              DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
            ],
            onChanged: (value) => setState(() => _method = value!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _reference,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: 'Referencia bancaria (opcional)',
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Guardando...' : 'Registrar adelanto'),
          ),
        ],
      ),
    ),
  );
}

class EditExpenseScreen extends StatefulWidget {
  const EditExpenseScreen({
    required this.gateway,
    required this.record,
    required this.dashboard,
    required this.rubrics,
    super.key,
  });
  final ExpensesGateway gateway;
  final ExpenseRecord record;
  final ExpenseDashboard dashboard;
  final ExpenseRubrics rubrics;

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _merchant;
  late final TextEditingController _reference;
  late final TextEditingController _description;
  late final TextEditingController _purpose;
  late final TextEditingController _fuelTime;
  late final TextEditingController _fuelPlate;
  late final TextEditingController _fuelProvince;
  late final TextEditingController _fuelCity;
  late DateTime _date;
  late String? _rubric;
  late int? _periodId;
  bool _saving = false;
  String? _error;

  bool get _travel => widget.record.type == 'travel_expense';
  List<String> get _rubrics =>
      _travel ? widget.rubrics.travel : widget.rubrics.benefits;
  bool get _isFuel =>
      _travel && {'combustible', 'peajes'}.contains(_rubric?.toLowerCase());
  List<ExpensePeriod> get _periods => widget.dashboard.periods
      .where(
        (item) =>
            item.circuit == (_travel ? 'travel_expense' : 'employee_benefit') &&
            {
              'open',
              'observed',
              'partially_observed',
              'partially_approved',
            }.contains(item.statusCode),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.record.amount?.toStringAsFixed(2),
    );
    _merchant = TextEditingController(text: widget.record.merchant);
    _reference = TextEditingController(text: widget.record.reference);
    _description = TextEditingController(text: widget.record.description);
    _purpose = TextEditingController(
      text: _travel ? widget.record.travelPurpose : widget.record.benefitName,
    );
    final fuel = widget.record.fuelEvidence ?? const <String, dynamic>{};
    _fuelTime = TextEditingController(text: fuel['ticket_time'] as String?);
    _fuelPlate = TextEditingController(text: fuel['vehicle_plate'] as String?);
    _fuelProvince = TextEditingController(text: fuel['province'] as String?);
    _fuelCity = TextEditingController(text: fuel['city'] as String?);
    _date = widget.record.date ?? DateTime.now();
    _rubric = _rubrics.contains(widget.record.rubric)
        ? widget.record.rubric
        : null;
    _periodId = _periods.any((item) => item.id == widget.record.periodId)
        ? widget.record.periodId
        : (_periods.isEmpty ? null : _periods.first.id);
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _reference.dispose();
    _description.dispose();
    _purpose.dispose();
    _fuelTime.dispose();
    _fuelPlate.dispose();
    _fuelProvince.dispose();
    _fuelCity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.updateRecord(
        widget.record.id,
        ExpenseUpdateDraft(
          expenseDate: _date,
          amount: double.parse(_amount.text.replaceAll(',', '.')),
          rubric: _rubric!,
          periodId: _periodId!,
          merchantName: _expenseNullable(_merchant.text),
          receiptReference: _expenseNullable(_reference.text),
          description: _expenseNullable(_description.text),
          travelPurpose: _travel ? _expenseNullable(_purpose.text) : null,
          benefitName: _travel ? null : _expenseNullable(_purpose.text),
          fuelTicketTime: _isFuel ? _expenseNullable(_fuelTime.text) : null,
          fuelVehiclePlate: _isFuel ? _expenseNullable(_fuelPlate.text) : null,
          fuelProvince: _isFuel ? _expenseNullable(_fuelProvince.text) : null,
          fuelCity: _isFuel ? _expenseNullable(_fuelCity.text) : null,
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
    appBar: AppBar(title: const Text('Editar comprobante')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _DateTile(
            label: 'Fecha del gasto',
            value: _date,
            onTap: () async {
              final value = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
              );
              if (value != null) setState(() => _date = value);
            },
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
            items: _rubrics
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _rubric = value),
            validator: (value) => value == null ? 'Seleccioná un rubro' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _periodId,
            decoration: const InputDecoration(labelText: 'Rendición'),
            items: _periods
                .map(
                  (value) => DropdownMenuItem(
                    value: value.id,
                    child: Text(value.label),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _periodId = value),
            validator: (value) =>
                value == null ? 'Seleccioná una rendición editable' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _purpose,
            decoration: InputDecoration(
              labelText: _travel ? 'Motivo del viaje' : 'Beneficio utilizado',
            ),
            validator: (value) => !_travel && (value ?? '').trim().isEmpty
                ? 'Indicá el beneficio utilizado'
                : null,
          ),
          if (_isFuel) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _fuelTime,
              decoration: const InputDecoration(
                labelText: 'Hora del ticket (HH:MM)',
              ),
              validator: (value) =>
                  RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                      .hasMatch((value ?? '').trim())
                  ? null
                  : 'Usá el formato HH:MM',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fuelPlate,
              decoration: const InputDecoration(labelText: 'Patente'),
              validator: (value) =>
                  (value ?? '').replaceAll(RegExp('[^A-Za-z0-9]'), '').length <
                      6
                  ? 'Ingresá una patente válida'
                  : null,
            ),
            if (_rubric?.toLowerCase() == 'combustible') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _fuelProvince,
                decoration: const InputDecoration(labelText: 'Provincia'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fuelCity,
                decoration: const InputDecoration(labelText: 'Ciudad'),
              ),
            ],
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _merchant,
            decoration: const InputDecoration(labelText: 'Comercio'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _reference,
            decoration: const InputDecoration(labelText: 'Referencia'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descripción'),
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
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
          ),
        ],
      ),
    ),
  );
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      child: Text(_expenseDate(value)),
    ),
  );
}

class _ReceiptDialog extends StatefulWidget {
  const _ReceiptDialog();

  @override
  State<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<_ReceiptDialog> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  DateTime _date = DateTime.now();
  String _method = 'transfer';

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirmar acreditación'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Importe recibido'),
          ),
          const SizedBox(height: 12),
          _DateTile(
            label: 'Fecha recibida',
            value: _date,
            onTap: () async {
              final value = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
              );
              if (value != null) setState(() => _date = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Medio'),
            items: const [
              DropdownMenuItem(value: 'transfer', child: Text('Transferencia')),
              DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
            ],
            onChanged: (value) => setState(() => _method = value!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reference,
            decoration: const InputDecoration(
              labelText: 'Referencia (opcional)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Volver'),
      ),
      FilledButton(
        onPressed: () {
          final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
          if (amount == null || amount <= 0) return;
          Navigator.pop(
            context,
            ExpenseReceiptDraft(
              amount: amount,
              receivedAt: _date,
              method: _method,
              bankReference: _expenseNullable(_reference.text),
            ),
          );
        },
        child: const Text('Confirmar'),
      ),
    ],
  );
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard(
    this.period, {
    this.onSubmit,
    this.onCorrection,
    this.onReceipt,
  });
  final ExpensePeriod period;
  final VoidCallback? onSubmit;
  final VoidCallback? onCorrection;
  final VoidCallback? onReceipt;
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
        if (onSubmit != null || onCorrection != null || onReceipt != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onSubmit != null)
                FilledButton.tonalIcon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Enviar'),
                ),
              if (onCorrection != null)
                OutlinedButton.icon(
                  onPressed: onCorrection,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('Solicitar corrección'),
                ),
              if (onReceipt != null)
                OutlinedButton.icon(
                  onPressed: onReceipt,
                  icon: const Icon(Icons.account_balance_outlined),
                  label: const Text('Confirmar acreditación'),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard(this.record, {this.onTap});
  final ExpenseRecord record;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
      ),
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

Future<String?> _textDialog(
  BuildContext context, {
  required String title,
  required String label,
}) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 6,
        maxLength: 4000,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.length >= 8) Navigator.pop(context, text);
          },
          child: const Text('Enviar'),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

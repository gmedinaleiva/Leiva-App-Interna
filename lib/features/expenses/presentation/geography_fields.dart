import 'package:flutter/material.dart';

import '../data/expenses_repository.dart';
import '../domain/expense_models.dart';

/// Fixed catalog choices, with local inline search and dependent localities.
class GeographyFields extends StatefulWidget {
  const GeographyFields({
    super.key,
    required this.gateway,
    required this.province,
    required this.city,
  });
  final ExpensesGateway gateway;
  final TextEditingController province;
  final TextEditingController city;
  @override
  State<GeographyFields> createState() => _GeographyFieldsState();
}

class _GeographyFieldsState extends State<GeographyFields> {
  List<GeographicOption> _provinces = [], _localities = [];
  GeographicOption? _province;
  bool _loading = true, _loadingCities = false;
  String? _error;
  int _generation = 0;
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
      final rows = await widget.gateway.provinces();
      if (!mounted) return;
      final current = rows
          .where((r) => r.name == widget.province.text)
          .firstOrNull;
      setState(() {
        _provinces = rows;
        _province = current;
        _loading = false;
      });
      if (current != null) await _loadCities(current);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No pudimos cargar las provincias. Reintentá.';
        });
      }
    }
  }

  Future<void> _loadCities(GeographicOption province) async {
    final generation = ++_generation;
    setState(() {
      _loadingCities = true;
      _localities = [];
      _error = null;
    });
    try {
      final rows = await widget.gateway.localities(province.id);
      if (!mounted || generation != _generation) return;
      setState(() {
        _localities = rows;
        _loadingCities = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loadingCities = false;
          _error = 'No pudimos cargar las localidades. Reintentá.';
        });
      }
    }
  }

  void _changeProvince(GeographicOption? value) {
    ++_generation;
    widget.city.clear();
    setState(() {
      _province = value;
      _localities = [];
      _loadingCities = false;
      _error = null;
    });
    if (value != null) _loadCities(value);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CatalogSearchField(
        label: 'Provincia',
        controller: widget.province,
        choices: _provinces,
        enabled: !_loading,
        onSelected: _changeProvince,
      ),
      const SizedBox(height: 16),
      CatalogSearchField(
        label: 'Localidad',
        controller: widget.city,
        choices: _localities,
        enabled: _province != null && !_loadingCities,
        hint: _province == null
            ? 'Primero seleccioná una provincia'
            : 'Escribí para buscar',
        onSelected: (_) {},
      ),
      if (_loading || _loadingCities)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(),
        ),
      if (_error != null)
        Row(
          children: [
            Expanded(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                if (_province != null) {
                  _loadCities(_province!);
                } else {
                  _load();
                }
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
    ],
  );
}

String _searchText(String value) {
  var text = value.toLowerCase();
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};
  accents.forEach((key, value) {
    text = text.replaceAll(key, value);
  });
  return text.trim();
}

class CatalogSearchField extends StatefulWidget {
  const CatalogSearchField({
    super.key,
    required this.label,
    required this.controller,
    required this.choices,
    required this.enabled,
    required this.onSelected,
    this.hint = 'Escribí para buscar',
  });
  final String label, hint;
  final TextEditingController controller;
  final List<GeographicOption> choices;
  final bool enabled;
  final ValueChanged<GeographicOption?> onSelected;
  @override
  State<CatalogSearchField> createState() => _CatalogSearchFieldState();
}

class _CatalogSearchFieldState extends State<CatalogSearchField> {
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => RawAutocomplete<GeographicOption>(
      textEditingController: widget.controller,
      focusNode: _focus,
      displayStringForOption: (option) => option.name,
      optionsBuilder: (value) => widget.enabled
          ? widget.choices.where(
              (r) => _searchText(r.name).contains(_searchText(value.text)),
            )
          : const [],
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, controller, focus, submit) => TextFormField(
        controller: controller,
        focusNode: focus,
        enabled: widget.enabled,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          suffixIcon: const Icon(Icons.search),
        ),
        onChanged: (_) => widget.onSelected(null),
        validator: (value) =>
            widget.enabled && widget.choices.any((r) => r.name == value)
            ? null
            : 'Seleccioná ${widget.label.toLowerCase()} de la lista',
        onFieldSubmitted: (_) => submit(),
      ),
      optionsViewBuilder: (context, select, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 5,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: constraints.maxWidth,
            height: 220,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options.elementAt(index);
                return ListTile(
                  title: Text(option.name),
                  onTap: () => select(option),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

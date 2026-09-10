import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../brew_models.dart';
import '../production_service.dart';

class BrewPortionPage extends StatefulWidget {
  const BrewPortionPage({
    super.key,
    required this.passportUid,
    required this.portionUid,
  });

  final String passportUid;
  final String portionUid;

  @override
  State<BrewPortionPage> createState() => _BrewPortionPageState();
}

class _BrewPortionPageState extends State<BrewPortionPage> {
  final Map<String, TextEditingController> _fields = {};
  BrewPortion? _standardPortion;
  final List<Map<String, dynamic>> _materialOptions = [];
  BrewPassport? _passport;
  BrewPortion? _portion;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  int _activeStep = 0;
  final List<Map<String, dynamic>> _materials = [];
  final List<Map<String, dynamic>> _mashPauses = [];
  final List<Map<String, dynamic>> _filtrationSteps = [];
  final List<Map<String, dynamic>> _additions = [];
  final List<Map<String, dynamic>> _operations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _field(String key) =>
      _fields.putIfAbsent(key, TextEditingController.new);

  Future<void> _load() async {
    try {
      final service = context.read<ProductionService>();
      final passport = await service.getBrewPassport(widget.passportUid);
      BrewPortion? portion;
      for (final item in passport.portions) {
        if (item.id == widget.portionUid) {
          portion = item;
          break;
        }
      }
      if (portion == null) throw Exception('Варку не знайдено');
      BrewPortion? standardPortion;
      for (final candidate in passport.portions) {
        if (candidate.id == portion.id) continue;
        if (candidate.mashPauses.isNotEmpty ||
            candidate.mashPh > 0 ||
            candidate.waterQuantity > 0 ||
            candidate.waterTemperature > 0) {
          standardPortion = candidate;
          break;
        }
      }
      final standardPauses = standardPortion?.mashPauses.isNotEmpty == true
          ? standardPortion!.mashPauses
          : passport.standard.mashPauses;
      if (portion.mashPauses.isEmpty && standardPauses.isNotEmpty) {
        _mashPauses
          ..clear()
          ..addAll(standardPauses.map((row) {
            final copy = _copyRow(row);
            copy['startedAt'] = '';
            copy['finishedAt'] = '';
            copy['actualTemperature'] = '';
            copy['comment'] = '';
            return copy;
          }));
      }
      _fillControllers(portion, preservePauseTemplate: _mashPauses.isNotEmpty);

      final materialOptions = <Map<String, dynamic>>[];
      try {
        final groups = await Future.wait([
          service.getCatalog(group: 'Зерно'),
          service.getCatalog(group: 'ХмельИДрожжи'),
          service.getCatalog(group: 'Компоненты'),
        ]);
        final seen = <String>{};
        for (final references in groups) {
          for (final item in references) {
            if (!seen.add(item.uid)) continue;
            materialOptions.add({
              'itemUid': item.uid,
              'itemName': item.name,
              'characteristicUid': '',
              'characteristicName': '',
              'unitUid': '',
              'unitName': '',
            });
          }
        }
      } catch (_) {
        // Додатковий список не повинен блокувати відкриття варки.
      }
      if (!mounted) return;
      setState(() {
        _passport = passport;
        _portion = portion;
        _standardPortion = standardPortion;
        _materialOptions
          ..clear()
          ..addAll(materialOptions);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _fillControllers(BrewPortion portion,
      {bool preservePauseTemplate = false}) {
    void number(String key, double value) {
      _field(key).text = value == 0 ? '' : _num(value);
    }

    number('mashPh', portion.mashPh);
    number('waterQuantity', portion.waterQuantity);
    number('waterTemperature', portion.waterTemperature);
    number('mashTunVolume', portion.mashTunVolume);
    _field('iodineTestAt').text = portion.iodineTestAt?.toIso8601String() ?? '';
    _field('boilStartedAt').text =
        portion.boilStartedAt?.toIso8601String() ?? '';
    _field('boilFinishedAt').text =
        portion.boilFinishedAt?.toIso8601String() ?? '';
    number('plannedBoilMinutes', portion.plannedBoilMinutes);
    number('preBoilVolume', portion.preBoilVolume);
    number('preBoilScaleVolume', portion.preBoilScaleVolume);
    number('preBoilDensity', portion.preBoilDensity);
    number('postBoilDensity', portion.postBoilDensity);
    number('whirlpoolVolume', portion.whirlpoolVolume);
    number('wortTemperature', portion.wortTemperature);
    _field('mashStartedAt').text = portion.startedAt?.toIso8601String() ?? '';
    _field('comment').text = portion.comment;
    _materials
      ..clear()
      ..addAll(portion.materials.map(_copyRow));
    if (!preservePauseTemplate) {
      _mashPauses
        ..clear()
        ..addAll(portion.mashPauses.map(_copyRow));
    }
    _filtrationSteps
      ..clear()
      ..addAll(portion.filtrationSteps.map(_copyRow));
    _additions
      ..clear()
      ..addAll(portion.additions.map(_copyRow));
    _operations
      ..clear()
      ..addAll(portion.operations.map(_copyRow));
  }

  Map<String, dynamic> _copyRow(Map<String, dynamic> row) =>
      Map<String, dynamic>.from(row);

  bool get _tableEditingEnabled => _portion?.finishedAt == null && !_busy;

  double _value(String key) =>
      double.tryParse(_field(key).text.trim().replaceAll(',', '.')) ?? 0;

  BrewPortionUpdate _update() => BrewPortionUpdate(
        id: widget.portionUid,
        mashStartedAt: DateTime.tryParse(_field('mashStartedAt').text),
        mashPh: _value('mashPh'),
        waterQuantity: _value('waterQuantity'),
        waterTemperature: _value('waterTemperature'),
        mashTunVolume: _value('mashTunVolume'),
        iodineTestAt: DateTime.tryParse(_field('iodineTestAt').text),
        boilStartedAt: DateTime.tryParse(_field('boilStartedAt').text),
        boilFinishedAt: DateTime.tryParse(_field('boilFinishedAt').text),
        plannedBoilMinutes: _value('plannedBoilMinutes'),
        preBoilVolume: _value('preBoilVolume'),
        preBoilScaleVolume: _value('preBoilScaleVolume'),
        preBoilDensity: _value('preBoilDensity'),
        postBoilDensity: _value('postBoilDensity'),
        whirlpoolVolume: _value('whirlpoolVolume'),
        wortTemperature: _value('wortTemperature'),
        comment: _field('comment').text,
        materials: _materials.map(_copyRow).toList(),
        mashPauses: _mashPauses.map(_copyRow).toList(),
        filtrationSteps: _filtrationSteps.map(_copyRow).toList(),
        additions: _additions.map(_copyRow).toList(),
        operations: _operations.map(_copyRow).toList(),
      );

  Widget _textCell(
    Map<String, dynamic> row,
    String key, {
    double width = 130,
    bool number = false,
    bool readOnly = false,
    String hint = '',
  }) {
    final value = row[key]?.toString() ?? '';
    if (readOnly) {
      return SizedBox(
        width: width,
        child: Text(value.isEmpty ? '—' : value, maxLines: 2),
      );
    }
    return SizedBox(
      width: width,
      child: TextFormField(
        key: ValueKey('${identityHashCode(row)}-$key-$value'),
        initialValue: value == '0' || value == '0.0' ? '' : value,
        enabled: _tableEditingEnabled,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: .28),
          hintText: hint,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide:
                BorderSide(color: Theme.of(context).colorScheme.primary),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        onChanged: (value) => row[key] = value,
      ),
    );
  }

  Widget _selectCell(
    Map<String, dynamic> row,
    String key,
    List<String> baseOptions, {
    double width = 180,
  }) {
    final current = row[key]?.toString() ?? '';
    final options = <String>{...baseOptions, if (current.isNotEmpty) current};
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: current.isEmpty ? null : current,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: .28),
          border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        ),
        items: options
            .map((value) => DropdownMenuItem(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: _tableEditingEnabled
            ? (value) => setState(() => row[key] = value ?? '')
            : null,
      ),
    );
  }

  Widget _timeCell(Map<String, dynamic> row, String key) {
    final raw = row[key]?.toString() ?? '';
    final parsed = DateTime.tryParse(raw);
    final label = parsed == null
        ? '—:—'
        : '${parsed.hour.toString().padLeft(2, '0')}:'
            '${parsed.minute.toString().padLeft(2, '0')}';
    return SizedBox(
      width: 105,
      child: OutlinedButton.icon(
        onPressed: _tableEditingEnabled
            ? () async {
                final selected = await _showCompactTimePicker(
                  parsed == null
                      ? TimeOfDay.now()
                      : TimeOfDay.fromDateTime(parsed),
                );
                if (selected == null || !mounted) return;
                final base = _portion?.brewDate ?? DateTime.now();
                final value = DateTime(
                  base.year,
                  base.month,
                  base.day,
                  selected.hour,
                  selected.minute,
                );
                setState(() => row[key] = value.toIso8601String());
              }
            : null,
        icon: const Icon(Icons.schedule_rounded, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _timeField(
    String key,
    String label, {
    required bool enabled,
  }) {
    final parsed = DateTime.tryParse(_field(key).text);
    final value = parsed == null
        ? '—:—'
        : '${parsed.hour.toString().padLeft(2, '0')}:'
            '${parsed.minute.toString().padLeft(2, '0')}';
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          OutlinedButton.icon(
            onPressed: !enabled
                ? null
                : () async {
                    final selected = await _showCompactTimePicker(
                      parsed == null
                          ? TimeOfDay.now()
                          : TimeOfDay.fromDateTime(parsed),
                    );
                    if (selected == null || !mounted) return;
                    final base = _portion?.brewDate ?? DateTime.now();
                    setState(() {
                      _field(key).text = DateTime(
                        base.year,
                        base.month,
                        base.day,
                        selected.hour,
                        selected.minute,
                      ).toIso8601String();
                    });
                  },
            icon: const Icon(Icons.schedule_rounded, size: 15),
            label: Text(value),
            style: OutlinedButton.styleFrom(
              shape: const RoundedRectangleBorder(),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _operation(String type) {
    for (final row in _operations) {
      if (row['operationType']?.toString() == type) return row;
    }
    return null;
  }

  Map<String, dynamic> _ensureOperation(String type) =>
      _operation(type) ??
      (_operations
            ..add({
              'operationType': type,
              'startedAt': '',
              'finishedAt': '',
              'quantity': '',
              'temperature': '',
              'comment': '',
            }))
          .last;

  Widget _operationTimes(String type, String label, bool completed) {
    final row = _operation(type);
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          TextButton.icon(
            onPressed: completed || _busy
                ? null
                : () async {
                    final target = row ?? _ensureOperation(type);
                    final raw = target['startedAt']?.toString() ?? '';
                    final parsed = DateTime.tryParse(raw);
                    final selected = await _showCompactTimePicker(
                      parsed == null
                          ? TimeOfDay.now()
                          : TimeOfDay.fromDateTime(parsed),
                    );
                    if (selected == null || !mounted) return;
                    final base = _portion?.brewDate ?? DateTime.now();
                    setState(() => target['startedAt'] = DateTime(
                          base.year,
                          base.month,
                          base.day,
                          selected.hour,
                          selected.minute,
                        ).toIso8601String());
                  },
            icon: const Icon(Icons.play_arrow_rounded, size: 15),
            label: Text(_timeLabel(row?['startedAt'])),
          ),
          const Text('—'),
          TextButton.icon(
            onPressed: completed || _busy
                ? null
                : () async {
                    final target = row ?? _ensureOperation(type);
                    final raw = target['finishedAt']?.toString() ?? '';
                    final parsed = DateTime.tryParse(raw);
                    final selected = await _showCompactTimePicker(
                      parsed == null
                          ? TimeOfDay.now()
                          : TimeOfDay.fromDateTime(parsed),
                    );
                    if (selected == null || !mounted) return;
                    final base = _portion?.brewDate ?? DateTime.now();
                    setState(() => target['finishedAt'] = DateTime(
                          base.year,
                          base.month,
                          base.day,
                          selected.hour,
                          selected.minute,
                        ).toIso8601String());
                  },
            icon: const Icon(Icons.stop_rounded, size: 15),
            label: Text(_timeLabel(row?['finishedAt'])),
          ),
        ],
      ),
    );
  }

  Widget _operationMinutes(String type, String label, bool completed) {
    final row = _operation(type);
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          SizedBox(
            width: 110,
            child: TextFormField(
              key: ValueKey('$type-${row?['quantity']}'),
              initialValue: row?['quantity']?.toString() ?? '',
              enabled: !completed && !_busy,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                suffixText: 'хв',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
              ),
              onChanged: (value) => _ensureOperation(type)['quantity'] = value,
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return '—:—';
    return '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  Future<TimeOfDay?> _showCompactTimePicker(TimeOfDay initial) async {
    final hour = TextEditingController(
      text: initial.hour.toString().padLeft(2, '0'),
    );
    final minute = TextEditingController(
      text: initial.minute.toString().padLeft(2, '0'),
    );
    String? error;

    void setTime(int totalMinutes, StateSetter setDialogState) {
      final normalized = ((totalMinutes % 1440) + 1440) % 1440;
      hour.text = (normalized ~/ 60).toString().padLeft(2, '0');
      minute.text = (normalized % 60).toString().padLeft(2, '0');
      setDialogState(() => error = null);
    }

    int currentMinutes() {
      final h = int.tryParse(hour.text) ?? 0;
      final m = int.tryParse(minute.text) ?? 0;
      return h * 60 + m;
    }

    final selected = await showDialog<TimeOfDay>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: const RoundedRectangleBorder(),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          title: const Text('Вказати час'),
          content: SizedBox(
            width: 330,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TimeNumberField(
                      controller: hour,
                      label: 'години',
                      autofocus: true,
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(10, 0, 10, 20),
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _TimeNumberField(
                      controller: minute,
                      label: 'хвилини',
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    OutlinedButton(
                      onPressed: () => setTime(
                        currentMinutes() - 5,
                        setDialogState,
                      ),
                      child: const Text('−5 хв'),
                    ),
                    OutlinedButton(
                      onPressed: () => setTime(
                        currentMinutes() + 5,
                        setDialogState,
                      ),
                      child: const Text('+5 хв'),
                    ),
                    OutlinedButton(
                      onPressed: () => setTime(
                        currentMinutes() + 10,
                        setDialogState,
                      ),
                      child: const Text('+10 хв'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final now = TimeOfDay.now();
                        setTime(now.hour * 60 + now.minute, setDialogState);
                      },
                      icon: const Icon(Icons.schedule_rounded, size: 16),
                      label: const Text('Зараз'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Скасувати'),
            ),
            FilledButton(
              onPressed: () {
                final h = int.tryParse(hour.text);
                final m = int.tryParse(minute.text);
                if (h == null ||
                    m == null ||
                    h < 0 ||
                    h > 23 ||
                    m < 0 ||
                    m > 59) {
                  setDialogState(
                    () => error = 'Вкажіть час від 00:00 до 23:59',
                  );
                  return;
                }
                Navigator.pop(dialogContext, TimeOfDay(hour: h, minute: m));
              },
              child: const Text('Застосувати'),
            ),
          ],
        ),
      ),
    );

    hour.dispose();
    minute.dispose();
    return selected;
  }

  void _fillMaterialsFromPlan() {
    if (!_tableEditingEnabled || _materials.isEmpty) return;
    setState(() {
      for (final row in _materials) {
        row['fact'] = row['plan'];
        row['deviationReason'] = '';
      }
    });
    _message('Фактичну кількість заповнено за планом');
  }

  Widget _rawMaterialSelectCell(Map<String, dynamic> row) {
    final candidates = <String, Map<String, dynamic>>{};
    void addCandidate(Map<String, dynamic> item) {
      final uid = item['itemUid']?.toString() ?? '';
      if (uid.isEmpty) return;
      final characteristicUid = item['characteristicUid']?.toString() ?? '';
      candidates['$uid|$characteristicUid'] = item;
    }

    for (final item in _materials) {
      addCandidate(item);
    }
    for (final item in _materialOptions) {
      addCandidate(item);
    }
    addCandidate(row);

    final current = '${row['itemUid'] ?? ''}|'
        '${row['characteristicUid'] ?? ''}';
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<String>(
        initialValue: candidates.containsKey(current) ? current : null,
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.zero),
        ),
        items: candidates.entries
            .map((entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(
                    entry.value['itemName']?.toString() ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        onChanged: !_tableEditingEnabled
            ? null
            : (value) {
                final selected = candidates[value];
                if (selected == null) return;
                setState(() {
                  row['itemUid'] = selected['itemUid'];
                  row['itemName'] = selected['itemName'];
                  row['characteristicUid'] =
                      selected['characteristicUid'] ?? '';
                  row['characteristicName'] =
                      selected['characteristicName'] ?? '';
                  row['unitUid'] = selected['unitUid'] ?? '';
                  row['unitName'] = selected['unitName'] ?? '';
                });
              },
      ),
    );
  }

  Widget _materialsTable(bool completed) => _EditableBrewTable(
        title: 'Сировина за рецептурою',
        icon: Icons.grain_rounded,
        rows: _materials,
        enabled: !completed,
        onAdd: _materialOptions.isEmpty
            ? null
            : () => setState(() => _materials.add({
                  'itemUid': '',
                  'itemName': '',
                  'characteristicUid': '',
                  'characteristicName': '',
                  'unitUid': '',
                  'unitName': '',
                  'plan': 0,
                  'fact': '',
                  'deviationReason': '',
                })),
        onDelete: (row) {
          final plan = double.tryParse(row['plan']?.toString() ?? '') ?? 0;
          if (plan != 0) {
            _message('Рядок рецептури видаляти не можна');
            return;
          }
          setState(() => _materials.remove(row));
        },
        headerAction: OutlinedButton.icon(
          onPressed: !completed && _materials.isNotEmpty
              ? _fillMaterialsFromPlan
              : null,
          icon: const Icon(Icons.playlist_add_check_rounded, size: 17),
          label: const Text('Заповнити за планом'),
          style: OutlinedButton.styleFrom(
            shape: const RoundedRectangleBorder(),
            visualDensity: VisualDensity.compact,
          ),
        ),
        emptyText: 'У документі немає рядків сировини',
        columns: [
          _BrewColumn(
              'N',
              38,
              (row) => SizedBox(
                    width: 38,
                    child: Text('${_materials.indexOf(row) + 1}',
                        textAlign: TextAlign.right),
                  )),
          _BrewColumn('Сировина', 260, _rawMaterialSelectCell),
          _BrewColumn(
              'Характеристика',
              150,
              (row) => _textCell(row, 'characteristicName',
                  width: 150, readOnly: true)),
          _BrewColumn('Од.', 80,
              (row) => _textCell(row, 'unitName', width: 80, readOnly: true)),
          _BrewColumn('План', 95,
              (row) => _textCell(row, 'plan', width: 95, readOnly: true)),
          _BrewColumn('Факт', 105,
              (row) => _textCell(row, 'fact', width: 105, number: true)),
          _BrewColumn('Причина відхилення', 230,
              (row) => _textCell(row, 'deviationReason', width: 230)),
        ],
      );

  Widget _pausesTable(bool completed) => _EditableBrewTable(
        title: 'Паузи затирання',
        icon: Icons.pause_circle_outline_rounded,
        rows: _mashPauses,
        enabled: !completed,
        onAdd: () => setState(() => _mashPauses.add({
              'number': _mashPauses.length + 1,
              'name': '',
              'plannedMinutes': '',
              'plannedTemperature': '',
              'startedAt': '',
              'finishedAt': '',
              'actualTemperature': '',
              'comment': '',
            })),
        onDelete: (row) => setState(() => _mashPauses.remove(row)),
        columns: [
          _BrewColumn('№', 55,
              (row) => _textCell(row, 'number', width: 55, number: true)),
          _BrewColumn(
              'Назва', 180, (row) => _textCell(row, 'name', width: 180)),
          _BrewColumn(
              'План, хв',
              95,
              (row) =>
                  _textCell(row, 'plannedMinutes', width: 95, number: true)),
          _BrewColumn(
              'План, °C',
              95,
              (row) => _textCell(row, 'plannedTemperature',
                  width: 95, number: true)),
          _BrewColumn('Початок', 105, (row) => _timeCell(row, 'startedAt')),
          _BrewColumn('Кінець', 105, (row) => _timeCell(row, 'finishedAt')),
          _BrewColumn(
              'Факт, °C',
              95,
              (row) =>
                  _textCell(row, 'actualTemperature', width: 95, number: true)),
          _BrewColumn(
              'Коментар', 190, (row) => _textCell(row, 'comment', width: 190)),
        ],
      );

  Widget _filtrationTable(bool completed) => _EditableBrewTable(
        title: 'Промивка',
        icon: Icons.filter_alt_outlined,
        rows: _filtrationSteps,
        enabled: !completed,
        onAdd: () => setState(() => _filtrationSteps.add({
              'number': _filtrationSteps.length + 1,
              'stageType': 'Промывка',
              'quantity': '',
              'startedAt': '',
              'finishedAt': '',
              'density': '',
              'temperature': '',
              'comment': '',
            })),
        onDelete: (row) => setState(() => _filtrationSteps.remove(row)),
        columns: [
          _BrewColumn('№', 55,
              (row) => _textCell(row, 'number', width: 55, number: true)),
          _BrewColumn(
              'Етап',
              175,
              (row) => _selectCell(
                  row, 'stageType', const ['Самотек', 'Промывка', 'Другое'],
                  width: 175)),
          _BrewColumn('Кількість', 105,
              (row) => _textCell(row, 'quantity', width: 105, number: true)),
          _BrewColumn('Початок', 105, (row) => _timeCell(row, 'startedAt')),
          _BrewColumn('Кінець', 105, (row) => _timeCell(row, 'finishedAt')),
          _BrewColumn('Щільність', 105,
              (row) => _textCell(row, 'density', width: 105, number: true)),
          _BrewColumn('Температура', 115,
              (row) => _textCell(row, 'temperature', width: 115, number: true)),
          _BrewColumn(
              'Коментар', 190, (row) => _textCell(row, 'comment', width: 190)),
        ],
      );

  Widget _materialSelectCell(Map<String, dynamic> row) {
    final current = row['itemUid']?.toString() ?? '';
    final candidates = <String, Map<String, dynamic>>{
      for (final material in _materials)
        if ((material['itemUid']?.toString() ?? '').isNotEmpty)
          material['itemUid'].toString(): material,
    };
    return SizedBox(
      width: 240,
      child: DropdownButtonFormField<String>(
        initialValue: candidates.containsKey(current) ? current : null,
        isExpanded: true,
        decoration: const InputDecoration(isDense: true),
        items: candidates.entries
            .map((entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value['itemName']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: !_tableEditingEnabled
            ? null
            : (value) {
                final material = candidates[value];
                if (material == null) return;
                setState(() {
                  row['itemUid'] = material['itemUid'];
                  row['itemName'] = material['itemName'];
                  row['characteristicUid'] = material['characteristicUid'];
                  row['characteristicName'] = material['characteristicName'];
                  row['unitUid'] = material['unitUid'];
                  row['unitName'] = material['unitName'];
                });
              },
      ),
    );
  }

  Widget _additionsTable(bool completed) => _EditableBrewTable(
        title: 'Внесення сировини та добавок',
        icon: Icons.add_circle_outline_rounded,
        rows: _additions,
        enabled: !completed,
        onAdd: _materials.isEmpty
            ? null
            : () => setState(() => _additions.add({
                  'stage': 'ПриКипячении',
                  'itemUid': '',
                  'itemName': '',
                  'quantity': '',
                  'addedAt': '',
                  'durationMinutes': '',
                  'comment': '',
                })),
        onDelete: (row) => setState(() => _additions.remove(row)),
        emptyText: _materials.isEmpty
            ? 'Спочатку в документі мають бути рядки сировини'
            : 'Додайте сировину або добавку та час внесення',
        columns: [
          _BrewColumn(
              'Етап',
              165,
              (row) => _selectCell(
                  row,
                  'stage',
                  const [
                    'ВЗатор',
                    'ВФильтрЧан',
                    'ПриПромывке',
                    'ПриКипячении',
                    'ВВирпул',
                    'ПриПерекачкеВЦКТ',
                    'Другое'
                  ],
                  width: 165)),
          _BrewColumn('Сировина / добавка', 240, _materialSelectCell),
          _BrewColumn('Кількість', 105,
              (row) => _textCell(row, 'quantity', width: 105, number: true)),
          _BrewColumn('Час', 105, (row) => _timeCell(row, 'addedAt')),
          _BrewColumn(
              'Тривалість, хв',
              120,
              (row) =>
                  _textCell(row, 'durationMinutes', width: 120, number: true)),
          _BrewColumn(
              'Коментар', 190, (row) => _textCell(row, 'comment', width: 190)),
        ],
      );

  Future<void> _run(String action) async {
    if (_busy || _portion == null) return;

    if (action == 'finish') {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Завершити варку?'),
              content: const Text(
                'Документ буде проведено. Після цього показники '
                'не можна буде змінити.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Скасувати'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Завершити'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;
    }

    FocusScope.of(context).unfocus();
    final service = context.read<ProductionService>();
    setState(() => _busy = true);
    try {
      final updated = await service.updateBrewPortion(
        _update(),
        action: action,
      );
      if (!mounted) return;
      _fillControllers(updated);
      setState(() {
        _portion = updated;
        _busy = false;
      });
      _message(switch (action) {
        'start' => 'Варку розпочато',
        'finish' => 'Варку завершено та проведено',
        _ => 'Показники збережено',
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message(_errorText(error));
    }
  }

  void _message(String text) {
    final hasActionBar = _portion?.finishedAt == null;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, hasActionBar ? 72 : 16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_errorText(_error), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Повторити'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final passport = _passport!;
    final portion = _portion!;
    final completed = portion.finishedAt != null;
    final started = portion.startedAt != null;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final standard = _standardPortion;
    final standardMashPh = (standard?.mashPh ?? 0) > 0
        ? standard!.mashPh
        : passport.standard.mashPh;
    final standardWaterQuantity = (standard?.waterQuantity ?? 0) > 0
        ? standard!.waterQuantity
        : passport.standard.waterQuantity;
    final standardWaterTemperature = (standard?.waterTemperature ?? 0) > 0
        ? standard!.waterTemperature
        : passport.standard.waterTemperature;
    final stepContent = switch (_activeStep) {
      0 => <Widget>[_materialsTable(completed)],
      1 => <Widget>[
          _Section(
            title: 'Затирання: стандарт і факт',
            icon: Icons.water_drop_outlined,
            children: [
              _timeField(
                'mashStartedAt',
                'Час початку затирання',
                enabled: !completed,
              ),
              _StandardNumberField(
                controller: _field('waterTemperature'),
                label: 'Температура води',
                standard: standardWaterTemperature,
                unit: '°C',
                enabled: !completed,
              ),
              _StandardNumberField(
                controller: _field('waterQuantity'),
                label: 'Кількість води',
                standard: standardWaterQuantity,
                unit: 'л',
                enabled: !completed,
              ),
              _timeField(
                'iodineTestAt',
                'Час йодної проби',
                enabled: !completed,
              ),
              _StandardNumberField(
                controller: _field('mashPh'),
                label: 'pH затору',
                standard: standardMashPh,
                enabled: !completed,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _pausesTable(completed),
          const SizedBox(height: 8),
          _Section(
            title: 'Перекачка',
            icon: Icons.sync_alt_rounded,
            singleColumn: true,
            children: [
              _operationTimes(
                'ПерекачкаВФильтрЧан',
                'Із заторника у фільтр-чан',
                completed,
              ),
            ],
          ),
        ],
      2 => <Widget>[
          _Section(
            title: 'Фільтрація',
            icon: Icons.filter_alt_outlined,
            children: [
              _NumberField(
                controller: _field('mashTunVolume'),
                label: 'Об’єм затору у фільтр-чані, л',
                enabled: !completed,
              ),
              _operationTimes('Байпас', 'Байпас', completed),
              _operationTimes('Настой', 'Настій', completed),
            ],
          ),
          const SizedBox(height: 8),
          _filtrationTable(completed),
        ],
      3 => <Widget>[
          _Section(
            title: 'Кип’ятіння',
            icon: Icons.local_fire_department_outlined,
            children: [
              _timeField(
                'boilStartedAt',
                'Початок кип’ятіння',
                enabled: !completed,
              ),
              _timeField(
                'boilFinishedAt',
                'Завершення кип’ятіння',
                enabled: !completed,
              ),
              _NumberField(
                controller: _field('plannedBoilMinutes'),
                label: 'План кип’ятіння, хв',
                enabled: !completed,
              ),
              _NumberField(
                controller: _field('preBoilVolume'),
                label: 'Об’єм перед кип’ятінням, л',
                enabled: !completed,
              ),
              _NumberField(
                controller: _field('preBoilScaleVolume'),
                label: 'Об’єм за палицею, л',
                enabled: !completed,
              ),
              _NumberField(
                controller: _field('preBoilDensity'),
                label: 'Щільність перед кип’ятінням',
                enabled: !completed,
              ),
              _NumberField(
                controller: _field('postBoilDensity'),
                label: 'Щільність після кип’ятіння',
                enabled: !completed,
              ),
              _operationTimes(
                'ПерекачкаВВирпул',
                'Перекачка у вірпул',
                completed,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _additionsTable(completed),
        ],
      _ => <Widget>[
          _Section(
            title: 'Вірпул',
            icon: Icons.cyclone_outlined,
            children: [
              _NumberField(
                controller: _field('whirlpoolVolume'),
                label: 'Об’єм у вірпулі, л',
                enabled: !completed,
              ),
              _operationMinutes(
                'НастойВВирпуле',
                'Настій у вірпулі',
                completed,
              ),
              _operationTimes(
                'ПерекачкаВЦКТ',
                'Перекачка в ЦКТ',
                completed,
              ),
              _operationTimes('Аэрация', 'Час аерації', completed),
              _NumberField(
                controller: _field('wortTemperature'),
                label: 'Температура сусла, °C',
                enabled: !completed,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: _field('comment'),
                enabled: !completed,
                maxLines: 2,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Коментар до варки',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ),
        ],
    };
    final actionButtons = <Widget>[
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _run('save'),
        icon: const Icon(Icons.save_outlined, size: 17),
        label: Text(started ? 'Зберегти зміни' : 'Зберегти чернетку'),
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          visualDensity: VisualDensity.compact,
        ),
      ),
      if (!started)
        FilledButton.icon(
          onPressed: _busy ? null : () => _run('start'),
          icon: const Icon(Icons.play_arrow_rounded, size: 17),
          label: const Text('Почати варку'),
          style: FilledButton.styleFrom(
            shape: const RoundedRectangleBorder(),
            visualDensity: VisualDensity.compact,
          ),
        ),
      if (started)
        FilledButton.icon(
          onPressed: _busy ? null : () => _run('finish'),
          icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
          label: const Text('Завершити варку'),
          style: FilledButton.styleFrom(
            shape: const RoundedRectangleBorder(),
            visualDensity: VisualDensity.compact,
          ),
        ),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            children: [
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Варка ${portion.portionNumber}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Партія #${passport.batchNumber} · '
                          '${passport.productName} · ${passport.cktName}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: portion.status, completed: completed),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow
                      .withValues(alpha: .45),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Wrap(
                  children: [
                    _Fact('Плановий об’єм', '${_num(portion.plannedVolume)} л'),
                    _Fact('Рецептура', portion.specificationName),
                    _Fact('Відповідальний', portion.responsibleName),
                    _Fact(
                      'Початок',
                      portion.startedAt == null
                          ? '—'
                          : _dateTime(portion.startedAt!),
                    ),
                    _Fact(
                      'Завершення',
                      portion.finishedAt == null
                          ? '—'
                          : _dateTime(portion.finishedAt!),
                    ),
                  ],
                ),
              ),
              if (completed) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: .1),
                    border: Border.all(color: cs.primary.withValues(alpha: .3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 17),
                      SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Варку завершено. Дані доступні тільки для перегляду.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _BrewProcessTabs(
                selected: _activeStep,
                onSelected: (value) => setState(() => _activeStep = value),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(
                    left: BorderSide(color: theme.dividerColor),
                    right: BorderSide(color: theme.dividerColor),
                    bottom: BorderSide(color: theme.dividerColor),
                  ),
                ),
                child: Column(children: stepContent),
              ),
            ],
          ),
        ),
        if (!completed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(top: BorderSide(color: theme.dividerColor)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: actionButtons,
            ),
          ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }
}

class _BrewProcessTabs extends StatelessWidget {
  const _BrewProcessTabs({
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  static const _items = [
    ('Сировина', Icons.grain_rounded),
    ('Затирання', Icons.water_drop_outlined),
    ('Фільтрація', Icons.filter_alt_outlined),
    ('Кип’ятіння', Icons.local_fire_department_outlined),
    ('Вірпул', Icons.cyclone_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < _items.length; index++)
              _BrewTabButton(
                label: _items[index].$1,
                icon: _items[index].$2,
                selected: selected == index,
                onTap: () => onSelected(index),
              ),
          ],
        ),
      ),
    );
  }
}

class _BrewTabButton extends StatelessWidget {
  const _BrewTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Transform.translate(
      offset: Offset(0, selected ? 1 : 0),
      child: Material(
        color: selected ? theme.cardColor : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          side: selected
              ? BorderSide(color: theme.dividerColor)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 108),
            padding: const EdgeInsets.fromLTRB(11, 7, 11, 8),
            decoration: selected
                ? BoxDecoration(
                    border: Border(
                      top: BorderSide(color: cs.primary, width: 2),
                      bottom: BorderSide(color: theme.cardColor, width: 2),
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(3)),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: selected ? cs.primary : null),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? cs.primary : null,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrewColumn {
  const _BrewColumn(this.label, this.width, this.builder);

  final String label;
  final double width;
  final Widget Function(Map<String, dynamic> row) builder;
}

class _EditableBrewTable extends StatelessWidget {
  const _EditableBrewTable({
    required this.title,
    required this.icon,
    required this.rows,
    required this.columns,
    required this.enabled,
    this.onAdd,
    this.onDelete,
    this.headerAction,
    this.emptyText = 'Немає рядків',
  });

  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> rows;
  final List<_BrewColumn> columns;
  final bool enabled;
  final VoidCallback? onAdd;
  final ValueChanged<Map<String, dynamic>>? onDelete;
  final Widget? headerAction;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.primary.withValues(alpha: .07),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 19, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                if (headerAction != null) ...[
                  headerAction!,
                  const SizedBox(width: 6),
                ],
                if (enabled && onAdd != null)
                  OutlinedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Додати'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(emptyText),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    horizontalMargin: 10,
                    columnSpacing: 8,
                    headingRowHeight: 32,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 42,
                    headingRowColor: WidgetStatePropertyAll(
                      theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: .34),
                    ),
                    border: TableBorder(
                      top: BorderSide(color: theme.dividerColor),
                      bottom: BorderSide(color: theme.dividerColor),
                      horizontalInside: BorderSide(color: theme.dividerColor),
                      verticalInside: BorderSide(color: theme.dividerColor),
                    ),
                    columns: [
                      ...columns.map((column) => DataColumn(
                            label: SizedBox(
                              width: column.width,
                              child: Text(column.label),
                            ),
                          )),
                      if (enabled && onDelete != null)
                        const DataColumn(label: SizedBox(width: 34)),
                    ],
                    rows: rows.asMap().entries.map((entry) {
                      final row = entry.value;
                      return DataRow(
                        key: ValueKey(identityHashCode(row)),
                        color: WidgetStatePropertyAll(
                          entry.key.isOdd
                              ? theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: .10)
                              : Colors.transparent,
                        ),
                        cells: [
                          ...columns.map(
                            (column) => DataCell(column.builder(row)),
                          ),
                          if (enabled && onDelete != null)
                            DataCell(IconButton(
                              tooltip: 'Видалити рядок',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => onDelete!(row),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 19,
                              ),
                            )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeNumberField extends StatelessWidget {
  const _TimeNumberField({
    required this.controller,
    required this.label,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 96,
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: InputDecoration(
            labelText: label,
            floatingLabelAlignment: FloatingLabelAlignment.center,
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.singleColumn = false,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool singleColumn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.primary.withValues(alpha: .07),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 19, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  !singleColumn && constraints.maxWidth >= 760 ? 2 : 1;
              final width = constraints.maxWidth / columns;
              return Wrap(
                children: [
                  for (final child in children)
                    SizedBox(width: width, child: child),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StandardNumberField extends StatelessWidget {
  const _StandardNumberField({
    required this.controller,
    required this.label,
    required this.standard,
    required this.enabled,
    this.unit = '',
  });

  final TextEditingController controller;
  final String label;
  final double standard;
  final bool enabled;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final standardText =
        standard > 0 ? '${_num(standard)}${unit.isEmpty ? '' : ' $unit'}' : '—';
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: theme.dividerColor),
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 175,
            constraints: const BoxConstraints(minHeight: 46),
            alignment: Alignment.centerLeft,
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: .32),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            width: 112,
            constraints: const BoxConstraints(minHeight: 46),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Стандарт', style: theme.textTheme.labelSmall),
                Text(
                  standardText,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Факт',
                suffixText: unit.isEmpty ? null : unit,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: theme.dividerColor),
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 210,
            constraints: const BoxConstraints(minHeight: 46),
            alignment: Alignment.centerLeft,
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: .32),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 220,
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '—' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.completed});
  final String status;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        completed ? Icons.check_rounded : Icons.timelapse_rounded,
        size: 17,
      ),
      label: Text(status.isEmpty ? 'Чернетка' : status),
      side: BorderSide(
        color: (completed ? cs.primary : cs.secondary).withValues(alpha: .45),
      ),
    );
  }
}

String _num(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';

String _dateTime(DateTime value) => '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.${value.year} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _errorText(Object? error) =>
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

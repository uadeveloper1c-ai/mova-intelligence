import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/session_store.dart';
import '../production_service.dart';

class ProductionTemplateDetailsPage extends StatefulWidget {
  const ProductionTemplateDetailsPage({super.key, required this.uid});

  final String uid;

  @override
  State<ProductionTemplateDetailsPage> createState() =>
      _ProductionTemplateDetailsPageState();
}

class _ProductionTemplateDetailsPageState
    extends State<ProductionTemplateDetailsPage> {
  late Future<_TemplateDetailsData> _future;
  List<SubdivisionAccess> _subdivisions = const [];
  String? _defaultSubdivisionUid;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await SessionStore.loadSession();
    if (mounted) {
      setState(() {
        _subdivisions = session?.subdivisions ?? const [];
        _defaultSubdivisionUid = session?.defaultSubdivisionUid;
      });
    }
  }

  Future<_TemplateDetailsData> _load() async {
    final service = context.read<ProductionService>();
    final template = await service.getTemplate(widget.uid);
    final stockByLine = <int, ProductionReference>{};

    await Future.wait([
      for (var i = 0; i < template.lines.length; i++)
        _loadLineStock(service, template, i).then((value) {
          if (value != null) stockByLine[i] = value;
        }),
    ]);

    return _TemplateDetailsData(template: template, stockByLine: stockByLine);
  }

  Future<ProductionReference?> _loadLineStock(
    ProductionService service,
    ProductionTemplate template,
    int index,
  ) async {
    final line = template.lines[index];
    if (line.itemUid.isEmpty) return null;
    try {
      final items = await service.searchCatalog(
        line.itemName,
        orgCode: template.organizationCode,
        templateType: template.templateType,
        group: line.group,
      );
      for (final item in items) {
        if (item.uid == line.itemUid) return item;
      }
    } catch (_) {
      // На просмотре не валим весь шаблон, если остаток одной строки не пришел.
    }
    return null;
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  String? _defaultTemplateSubdivisionUid() {
    final defaultUid = _defaultSubdivisionUid?.trim() ?? '';
    if (defaultUid.isNotEmpty &&
        _subdivisions.any((item) => item.uid == defaultUid)) {
      return defaultUid;
    }
    if (_subdivisions.length == 1) return _subdivisions.first.uid;
    return null;
  }

  Future<void> _createOrders(ProductionTemplate template) async {
    final volume = TextEditingController(
      text: template.baseVolume.toStringAsFixed(
        template.baseVolume == template.baseVolume.roundToDouble() ? 0 : 2,
      ),
    );
    final comment = TextEditingController();
    var date = DateTime.now();
    String? subdivisionUid = _defaultTemplateSubdivisionUid();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Створити переміщення за шаблоном «${template.name}»'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: volume,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Обсяг'),
                ),
                const SizedBox(height: 12),
                if (_subdivisions.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: subdivisionUid,
                    decoration: const InputDecoration(labelText: 'Підрозділ'),
                    items: [
                      for (final subdivision in _subdivisions)
                        DropdownMenuItem(
                          value: subdivision.uid,
                          child: Text(subdivision.name),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => subdivisionUid = value),
                  ),
                  const SizedBox(height: 12),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Бажана дата'),
                  subtitle: Text(_formatDate(date)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (selected != null) {
                      setDialogState(() => date = selected);
                    }
                  },
                ),
                TextField(
                  controller: comment,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Коментар'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Скасувати'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Створити переміщення'),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) {
      volume.dispose();
      comment.dispose();
      return;
    }
    try {
      final parsed = double.tryParse(volume.text.replaceAll(',', '.'));
      if (parsed == null || parsed <= 0) {
        throw Exception('Вкажіть коректний обсяг');
      }
      await context.read<ProductionService>().createFromTemplate(
            templateUid: template.uid,
            volume: parsed,
            requiredDate: date,
            subdivisionUid: subdivisionUid ?? '',
            comment: comment.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Виробничі замовлення створено')),
        );
      }
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      volume.dispose();
      comment.dispose();
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error'), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_TemplateDetailsData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final template = data?.template;
          return ListView(
            padding: EdgeInsets.all(desktop ? 20 : 12),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Назад',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template?.name ?? 'Виробничий шаблон',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Склад, нормативи та поточні залишки',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: .6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (template != null) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        await context
                            .push('/production/templates/${template.uid}');
                        if (mounted) await _refresh();
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Редагувати'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => _createOrders(template),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Створити переміщення'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState != ConnectionState.done)
                const SizedBox(
                  height: 320,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _MessagePanel(
                  icon: Icons.cloud_off_outlined,
                  title: 'Не вдалося завантажити шаблон',
                  subtitle: '${snapshot.error}',
                  action: _refresh,
                )
              else if (data != null) ...[
                _TemplateSummary(template: data.template),
                const SizedBox(height: 14),
                _TemplateLinesTable(
                  template: data.template,
                  stockByLine: data.stockByLine,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TemplateSummary extends StatelessWidget {
  const _TemplateSummary({required this.template});

  final ProductionTemplate template;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Wrap(
        spacing: 0,
        runSpacing: 0,
        children: [
          _InfoChip(label: 'Організація', value: template.organizationName),
          _InfoChip(label: 'Вид', value: template.templateType),
          _InfoChip(label: 'Напій', value: template.drinkType),
          _InfoChip(
              label: 'Обсяг', value: _formatQuantity(template.baseVolume)),
          _InfoChip(label: 'Позицій', value: '${template.lines.length}'),
          _InfoChip(
            label: 'Стан',
            value: template.active ? 'Активний' : 'Неактивний',
            valueColor: template.active ? cs.primary : cs.error,
          ),
          if (template.productName.isNotEmpty)
            _InfoChip(label: 'Продукція', value: template.productName),
          if (template.comment.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: Text(
                template.comment,
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: 210,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: cs.outlineVariant),
          bottom: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.isEmpty ? '—' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateLinesTable extends StatelessWidget {
  const _TemplateLinesTable({
    required this.template,
    required this.stockByLine,
  });

  final ProductionTemplate template;
  final Map<int, ProductionReference> stockByLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isNarrow = MediaQuery.sizeOf(context).width < 760;

    if (isNarrow) {
      return Column(
        children: [
          for (var i = 0; i < template.lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LineCard(
                line: template.lines[i],
                stock: stockByLine[i],
              ),
            ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: .35),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                _HeaderCell('Група', flex: 2),
                _HeaderCell('Номенклатура', flex: 5),
                _HeaderCell('Кількість', flex: 1, alignRight: true),
                _HeaderCell('Залишок', flex: 2, alignRight: true),
                _HeaderCell('Коментар', flex: 3),
                const SizedBox(width: 32),
              ],
            ),
          ),
          for (var i = 0; i < template.lines.length; i++)
            _LineRow(
              line: template.lines[i],
              stock: stockByLine[i],
              showDivider: i < template.lines.length - 1,
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {required this.flex, this.alignRight = false});

  final String text;
  final int flex;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.stock,
    required this.showDivider,
  });

  final ProductionTemplateLine line;
  final ProductionReference? stock;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stockValue = stock?.stock;
    final stockText = stockValue == null
        ? '—'
        : [
            _formatQuantity(stockValue),
            stock?.stockUnit ?? '',
          ].where((part) => part.isNotEmpty).join(' ');
    final stockColor = stockValue == null
        ? cs.onSurfaceVariant
        : stockValue <= 0
            ? cs.error
            : cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: cs.outlineVariant))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(line.group),
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                line.itemName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _formatQuantity(line.quantity),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                stockText,
                textAlign: TextAlign.right,
                style:
                    TextStyle(color: stockColor, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                line.comment.isEmpty ? '—' : line.comment,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Icon(
              line.required
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 20,
              color: line.required ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.stock,
  });

  final ProductionTemplateLine line;
  final ProductionReference? stock;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stockValue = stock?.stock;
    final stockText = stockValue == null
        ? '—'
        : [
            _formatQuantity(stockValue),
            stock?.stockUnit ?? '',
          ].where((part) => part.isNotEmpty).join(' ');
    final stockColor = stockValue == null
        ? cs.onSurfaceVariant
        : stockValue <= 0
            ? cs.error
            : cs.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.itemName,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _SmallMetric(label: 'Група', value: line.group),
              _SmallMetric(
                label: 'Кількість',
                value: _formatQuantity(line.quantity),
              ),
              _SmallMetric(
                label: 'Залишок',
                value: stockText,
                valueColor: stockColor,
              ),
              _SmallMetric(
                label: 'Обовʼязково',
                value: line.required ? 'Так' : 'Ні',
              ),
            ],
          ),
          if (line.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(line.comment, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: action,
              child: const Text('Продовжити'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateDetailsData {
  const _TemplateDetailsData({
    required this.template,
    required this.stockByLine,
  });

  final ProductionTemplate template;
  final Map<int, ProductionReference> stockByLine;
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String _formatQuantity(double value) {
  return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 3);
}

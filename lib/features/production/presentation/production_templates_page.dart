import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/session_store.dart';
import '../production_service.dart';

class ProductionTemplatesPage extends StatefulWidget {
  const ProductionTemplatesPage({super.key});

  @override
  State<ProductionTemplatesPage> createState() =>
      _ProductionTemplatesPageState();
}

class _ProductionTemplatesPageState extends State<ProductionTemplatesPage> {
  late Future<List<ProductionTemplate>> _future;
  List<SubdivisionAccess> _subdivisions = const [];
  String? _defaultSubdivisionUid;

  @override
  void initState() {
    super.initState();
    _future = context.read<ProductionService>().getTemplates();
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

  Future<void> _refresh() async {
    final future = context.read<ProductionService>().getTemplates();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openEditor([ProductionTemplate? template]) async {
    final path = template == null
        ? '/production/templates/new'
        : '/production/templates/${template.uid}';
    await context.push(path);
    if (mounted) await _refresh();
  }

  Future<void> _openDetails(ProductionTemplate template) async {
    await context.push('/production/templates/view/${template.uid}');
    if (mounted) await _refresh();
  }

  Future<void> _copy(ProductionTemplate template) async {
    final controller = TextEditingController(text: 'Копія ${template.name}');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Копіювати шаблон'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Назва нового шаблону'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Копіювати'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await context.read<ProductionService>().copyTemplate(template.uid, name);
      if (mounted) await _refresh();
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _archive(ProductionTemplate template) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Архівувати шаблон?'),
            content: Text(template.name),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Скасувати'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Архівувати'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      await context.read<ProductionService>().archiveTemplate(template.uid);
      if (mounted) await _refresh();
    } catch (e) {
      if (mounted) _showError(e);
    }
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
                  subtitle: Text(
                    '${date.day.toString().padLeft(2, '0')}.'
                    '${date.month.toString().padLeft(2, '0')}.${date.year}',
                  ),
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
      child: ListView(
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
                      'Виробничі шаблони',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Рецептури та склад майбутніх переміщень',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: .6),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _openEditor,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Новий шаблон'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<ProductionTemplate>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _MessagePanel(
                  icon: Icons.cloud_off_outlined,
                  title: 'Не вдалося завантажити шаблони',
                  subtitle: '${snapshot.error}',
                  action: _refresh,
                );
              }
              final templates = snapshot.data ?? const [];
              if (templates.isEmpty) {
                return _MessagePanel(
                  icon: Icons.library_add_outlined,
                  title: 'Шаблонів ще немає',
                  subtitle: 'Створіть першу рецептуру для виробничої заявки.',
                  action: _openEditor,
                );
              }
              return _TemplatesTable(
                templates: templates,
                onOpen: _openDetails,
                onCopy: _copy,
                onArchive: _archive,
                onCreateOrders: _createOrders,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TemplatesTable extends StatelessWidget {
  const _TemplatesTable({
    required this.templates,
    required this.onOpen,
    required this.onCopy,
    required this.onArchive,
    required this.onCreateOrders,
  });

  final List<ProductionTemplate> templates;
  final ValueChanged<ProductionTemplate> onOpen;
  final ValueChanged<ProductionTemplate> onCopy;
  final ValueChanged<ProductionTemplate> onArchive;
  final ValueChanged<ProductionTemplate> onCreateOrders;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowHeight: 36,
          dataRowMinHeight: 46,
          dataRowMaxHeight: 52,
          horizontalMargin: 12,
          columnSpacing: 22,
          border: TableBorder.all(color: cs.outlineVariant),
          columns: const [
            DataColumn(label: Text('Шаблон')),
            DataColumn(label: Text('Організація')),
            DataColumn(label: Text('Тип')),
            DataColumn(label: Text('Напій')),
            DataColumn(label: Text('Базовий обсяг'), numeric: true),
            DataColumn(label: Text('Позицій'), numeric: true),
            DataColumn(label: Text('Команди')),
          ],
          rows: [
            for (final template in templates)
              DataRow(
                onSelectChanged: (_) => onOpen(template),
                cells: [
                  DataCell(SizedBox(
                    width: 280,
                    child: Text(template.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  )),
                  DataCell(SizedBox(
                      width: 180, child: Text(template.organizationName))),
                  DataCell(Text(template.templateType)),
                  DataCell(Text(template.drinkType)),
                  DataCell(Text('${template.baseVolume}')),
                  DataCell(Text('${template.lines.length}')),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Створити переміщення',
                        onPressed: () => onCreateOrders(template),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Копіювати',
                        onPressed: () => onCopy(template),
                        icon: const Icon(Icons.copy_outlined, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Архівувати',
                        onPressed: () => onArchive(template),
                        icon: const Icon(Icons.archive_outlined, size: 18),
                      ),
                    ],
                  )),
                ],
              ),
          ],
        ),
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

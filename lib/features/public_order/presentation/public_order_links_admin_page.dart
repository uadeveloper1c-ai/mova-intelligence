import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../sales/sales_service.dart';
import '../public_order_link_admin_service.dart';

class PublicOrderLinksAdminPage extends StatefulWidget {
  const PublicOrderLinksAdminPage({super.key});

  @override
  State<PublicOrderLinksAdminPage> createState() =>
      _PublicOrderLinksAdminPageState();
}

class _PublicOrderLinksAdminPageState extends State<PublicOrderLinksAdminPage> {
  final _partnerController = TextEditingController();
  final _commentController = TextEditingController();
  Timer? _debounce;

  SalesReference? _partner;
  SalesReference? _agreement;
  List<SalesReference> _partnerOptions = const [];
  List<SalesReference> _agreements = const [];
  PublicOrderLinkInfo? _link;
  DateTime _expirationDate = DateTime.now().add(const Duration(days: 30));
  bool _searching = false;
  bool _loading = false;
  bool _saving = false;
  bool _syncingPartnerText = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _partnerController.addListener(_onPartnerTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _partnerController.removeListener(_onPartnerTextChanged);
    _partnerController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  SalesService get _sales => context.read<SalesService>();
  PublicOrderLinkAdminService get _links =>
      context.read<PublicOrderLinkAdminService>();

  void _onPartnerTextChanged() {
    if (_syncingPartnerText) return;
    final value = _partnerController.text;
    if (_partner != null && value != _partner!.name) {
      setState(() {
        _partner = null;
        _link = null;
        _agreement = null;
      });
    }
    _schedulePartnerSearch(value);
  }

  void _schedulePartnerSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final options = await _sales.searchPartners(value);
        if (mounted) setState(() => _partnerOptions = options);
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _selectPartner(SalesReference partner) async {
    _debounce?.cancel();
    _syncingPartnerText = true;
    _partnerController.text = partner.name;
    _partnerController.selection = TextSelection.collapsed(
      offset: _partnerController.text.length,
    );
    _syncingPartnerText = false;
    setState(() {
      _partner = partner;
      _partnerOptions = const [];
      _agreement = null;
      _agreements = const [];
      _link = null;
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _sales.getAgreements(partner.uid),
        _links.getByPartner(partner.uid),
      ]);
      final agreements = results[0] as List<SalesReference>;
      final link = results[1] as PublicOrderLinkInfo;
      SalesReference? selected;
      if (link.agreementUid.isNotEmpty) {
        for (final item in agreements) {
          if (item.uid == link.agreementUid) {
            selected = item;
            break;
          }
        }
        selected ??= SalesReference(
          uid: link.agreementUid,
          name: link.agreementName,
          warehouseName: link.warehouseName,
          organizationName: link.organizationName,
        );
      }
      if (!mounted) return;
      setState(() {
        _agreements = selected != null &&
                !agreements.any((item) => item.uid == selected!.uid)
            ? [...agreements, selected]
            : agreements;
        _agreement = selected;
        _link = link;
        _commentController.text = link.comment;
        _expirationDate =
            link.expirationDate ?? DateTime.now().add(const Duration(days: 30));
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _expirationDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (result != null && mounted) {
      setState(() => _expirationDate = result);
    }
  }

  String get _publicUrl {
    final token = _link?.token ?? '';
    if (token.isEmpty) return '';
    final origin = Uri.base.hasAuthority
        ? '${Uri.base.scheme}://${Uri.base.authority}'
        : 'https://intelligence.mova.beer';
    return '$origin/app/#/public-order?token=${Uri.encodeQueryComponent(token)}';
  }

  Future<void> _save({required bool regenerate}) async {
    final partner = _partner;
    final agreement = _agreement;
    if (partner == null) {
      setState(() => _error = 'Оберіть партнера');
      return;
    }
    if (agreement == null) {
      setState(() => _error = 'Оберіть оферту');
      return;
    }
    if (regenerate && _link?.exists == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Створити нове посилання?'),
          content: const Text(
            'Поточне посилання одразу перестане працювати.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Скасувати'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Створити нове'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final link = await _links.save(
        partnerUid: partner.uid,
        agreementUid: agreement.uid,
        expirationDate: _expirationDate,
        comment: _commentController.text,
        regenerate: regenerate,
      );
      if (!mounted) return;
      setState(() => _link = link);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(regenerate
              ? 'Нове посилання створено'
              : 'Налаштування збережено'),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyLink() async {
    if (_publicUrl.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _publicUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Посилання скопійовано')),
    );
  }

  Future<void> _shareTelegram() async {
    if (_publicUrl.isEmpty) return;
    final uri = Uri.https('t.me', '/share/url', {
      'url': _publicUrl,
      'text': 'Ваше персональне посилання для замовлення продукції MOVA',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedAgreement = _agreement;
    final current = _link;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Назад',
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Посилання для партнерів',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Персональний каталог, залишки, ціни та замовлення',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Партнер',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _partnerController,
                decoration: InputDecoration(
                  labelText: 'Почніть вводити назву партнера',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              ),
              if (_partnerOptions.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _partnerOptions.length,
                    itemBuilder: (context, index) {
                      final item = _partnerOptions[index];
                      return ListTile(
                        title: Text(item.name),
                        onTap: () => _selectPartner(item),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_loading) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_partner != null && !_loading) ...[
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final settings = _SettingsPanel(
                agreements: _agreements,
                agreement: _agreement,
                expirationDate: _expirationDate,
                commentController: _commentController,
                onAgreementChanged: (value) =>
                    setState(() => _agreement = value),
                onPickDate: _pickDate,
                formatDate: _formatDate,
              );
              final status = _LinkStatusPanel(
                link: current,
                agreement: selectedAgreement,
                publicUrl: _publicUrl,
                onCopy: _copyLink,
                onTelegram: _shareTelegram,
              );
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: settings),
                        const SizedBox(width: 14),
                        Expanded(flex: 5, child: status),
                      ],
                    )
                  : Column(
                      children: [
                        settings,
                        const SizedBox(height: 14),
                        status,
                      ],
                    );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _save(regenerate: true),
                icon: const Icon(Icons.autorenew_rounded),
                label: Text(
                  current?.exists == true
                      ? 'Згенерувати нове посилання'
                      : 'Згенерувати посилання',
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(regenerate: false),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Зберегти'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.agreements,
    required this.agreement,
    required this.expirationDate,
    required this.commentController,
    required this.onAgreementChanged,
    required this.onPickDate,
    required this.formatDate,
  });

  final List<SalesReference> agreements;
  final SalesReference? agreement;
  final DateTime expirationDate;
  final TextEditingController commentController;
  final ValueChanged<SalesReference?> onAgreementChanged;
  final VoidCallback onPickDate;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Налаштування',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<SalesReference>(
            initialValue: agreement,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Оферта'),
            items: agreements
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      item.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onAgreementChanged,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Діє до',
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
              child: Text(formatDate(expirationDate)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: commentController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Коментар',
              alignLabelWithHint: true,
            ),
          ),
          if (agreement != null) ...[
            const SizedBox(height: 14),
            _FactRow('Організація', agreement!.organizationName),
            _FactRow('Склад', agreement!.warehouseName),
            _FactRow('Вид цін', agreement!.priceTypeName),
          ],
        ],
      ),
    );
  }
}

class _LinkStatusPanel extends StatelessWidget {
  const _LinkStatusPanel({
    required this.link,
    required this.agreement,
    required this.publicUrl,
    required this.onCopy,
    required this.onTelegram,
  });

  final PublicOrderLinkInfo? link;
  final SalesReference? agreement;
  final String publicUrl;
  final VoidCallback onCopy;
  final VoidCallback onTelegram;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final exists = link?.exists == true;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Поточне посилання',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Icon(
                exists ? Icons.check_circle_rounded : Icons.link_off_rounded,
                color: exists ? cs.primary : cs.outline,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!exists)
            const Text(
              'Активного токена немає. Оберіть оферту та згенеруйте посилання.',
            )
          else ...[
            SelectableText(
              publicUrl,
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _FactRow('Контрагент', link!.contractorName),
            _FactRow('Організація', link!.organizationName),
            _FactRow('Оферта', link!.agreementName),
            _FactRow('Склад', link!.warehouseName),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Копіювати'),
                ),
                OutlinedButton.icon(
                  onPressed: onTelegram,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Telegram'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: .62),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

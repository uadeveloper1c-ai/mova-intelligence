import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../api/api_client.dart';
import '../public_order_service.dart';

const _b2bInk = Color(0xFF172033);
const _b2bMuted = Color(0xFF667085);
const _b2bBg = Color(0xFFF5F8FB);
const _b2bBgTop = Color(0xFFE9F6F3);
const _b2bBgBottom = Color(0xFFEEF4FF);
const _b2bSurface = Colors.white;
const _b2bSurfaceSoft = Color(0xFFF8FAFC);
const _b2bLine = Color(0xFFD7E2EC);
const _b2bAccent = Color(0xFF0F766E);
const _b2bBlue = Color(0xFF2563EB);
const _b2bCoral = Color(0xFFFF7A45);
const _b2bGold = Color(0xFFF4B740);
const _b2bDanger = Color(0xFFDC2626);

List<BoxShadow> get _b2bShadow => [
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: .08),
        blurRadius: 28,
        offset: const Offset(0, 18),
      ),
    ];

ThemeData _publicOrderTheme(BuildContext context) {
  final base = Theme.of(context);
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: _b2bLine),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _b2bAccent,
      brightness: Brightness.light,
    ).copyWith(
      primary: _b2bAccent,
      onPrimary: Colors.white,
      secondary: _b2bBlue,
      surface: _b2bSurface,
      onSurface: _b2bInk,
      error: _b2bDanger,
      errorContainer: const Color(0xFFFFE4E6),
      onErrorContainer: const Color(0xFF9F1239),
      primaryContainer: const Color(0xFFDDF7F3),
      onPrimaryContainer: const Color(0xFF064E3B),
      outline: _b2bLine,
      outlineVariant: _b2bLine,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: _b2bInk,
      displayColor: _b2bInk,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _b2bAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _b2bAccent,
        side: const BorderSide(color: _b2bLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _b2bSurfaceSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: _b2bAccent, width: 1.4),
      ),
    ),
    dividerTheme: const DividerThemeData(color: _b2bLine),
  );
}

class PublicOrderPage extends StatefulWidget {
  const PublicOrderPage({super.key, required this.token});

  final String token;

  @override
  State<PublicOrderPage> createState() => _PublicOrderPageState();
}

class _PublicOrderPageState extends State<PublicOrderPage> {
  late final PublicOrderService _service;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _commentCtrl = TextEditingController();
  final Map<String, TextEditingController> _qtyCtrls = {};
  Timer? _debounce;

  PublicOrderForm? _form;
  List<PublicOrderItem> _items = const [];
  List<PublicOrderHistoryOrder> _history = const [];
  final List<PublicOrderLine> _lines = [];
  bool _loading = true;
  bool _searching = false;
  bool _submitting = false;
  bool _cartSheetOpen = false;
  bool _historyLoading = false;
  int _selectedWorkspace = 0;
  String? _paymentForm;
  String _cashMethod = 'fact';
  String? _error;
  String? _historyError;
  String? _success;
  PublicOrderSubmitResult? _completedOrder;

  @override
  void initState() {
    super.initState();
    _service = PublicOrderService(context.read<ApiClient>());
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _commentCtrl.dispose();
    for (final ctrl in _qtyCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final form = await _service.getForm(widget.token);
      final items = await _service.searchCatalog(
        token: widget.token,
        query: '',
      );
      if (!mounted) return;
      setState(() {
        _form = form;
        _items = items;
        _commentCtrl.text = form.comment;
        _paymentForm = form.paymentOptions.length == 1
            ? form.paymentOptions.first.code
            : null;
      });
      unawaited(_loadHistory());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final history = await _service.getHistory(widget.token);
      if (!mounted) return;
      setState(() => _history = history);
    } catch (e) {
      if (mounted) {
        setState(
            () => _historyError = 'Історія замовлень тимчасово недоступна');
      }
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final items = await _service.searchCatalog(
        token: widget.token,
        query: query,
      );
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _addItem(PublicOrderItem item) async {
    if (item.stock <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Цього товару зараз немає в наявності')),
      );
      return;
    }
    final defaultQty = item.boxQuantity > 0 ? item.boxQuantity : 1.0;
    final quantity = await _askQuantity(item, defaultQty);
    if (!mounted || quantity == null || quantity <= 0) return;
    final existing = _lines.indexWhere((line) => line.item.uid == item.uid);
    setState(() {
      if (existing >= 0) {
        final old = _lines[existing];
        _lines[existing] = PublicOrderLine(
          item: old.item,
          quantity: old.quantity + quantity,
        );
      } else {
        _lines.add(PublicOrderLine(item: item, quantity: quantity));
      }
      _syncQtyCtrl(item.uid);
    });
  }

  Future<double?> _askQuantity(PublicOrderItem item, double defaultQty) async {
    final ctrl = TextEditingController(text: _formatNumber(defaultQty));
    String? errorText;
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double? parseQty() {
              final qty =
                  double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              if (qty == null || qty <= 0) {
                setDialogState(() => errorText = 'Вкажіть кількість більше 0');
                return null;
              }
              return qty;
            }

            return AlertDialog(
              title: const Text('Кількість'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    if (item.boxQuantity > 0) ...[
                      const SizedBox(height: 6),
                      Text('Ящик: ${_formatNumber(item.boxQuantity)}'),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Скільки додати',
                        errorText: errorText,
                      ),
                      onChanged: (_) {
                        if (errorText != null) {
                          setDialogState(() => errorText = null);
                        }
                      },
                      onSubmitted: (_) {
                        final qty = parseQty();
                        if (qty != null) Navigator.of(context).pop(qty);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Скасувати'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final qty = parseQty();
                    if (qty != null) Navigator.of(context).pop(qty);
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Додати'),
                ),
              ],
            );
          },
        );
      },
    );
    ctrl.dispose();
    return result;
  }

  void _removeLine(String uid) {
    setState(() {
      _lines.removeWhere((line) => line.item.uid == uid);
      _qtyCtrls.remove(uid)?.dispose();
    });
  }

  TextEditingController _syncQtyCtrl(String uid) {
    final line = _lines.firstWhere((line) => line.item.uid == uid);
    final ctrl = _qtyCtrls.putIfAbsent(uid, () => TextEditingController());
    final text = _formatNumber(line.quantity);
    if (ctrl.text != text) ctrl.text = text;
    return ctrl;
  }

  void _setQuantity(PublicOrderLine line, String value) {
    final qty = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    final index = _lines.indexWhere((item) => item.item.uid == line.item.uid);
    if (index < 0) return;
    setState(() {
      _lines[index] = PublicOrderLine(
        item: line.item,
        quantity: qty < 0 ? 0 : qty,
      );
    });
  }

  Future<void> _submit() async {
    final form = _form;
    if (form == null || form.paymentOptions.isEmpty) {
      setState(() => _error = 'Для партнера не налаштовані договори оплати');
      return;
    }
    if (_paymentForm == null || _paymentForm!.isEmpty) {
      setState(() => _error = 'Оберіть форму оплати');
      return;
    }
    final validLines = _lines.where((line) => line.quantity > 0).toList();
    if (validLines.isEmpty) {
      setState(() => _error = 'Додайте хоча б один товар');
      return;
    }
    final unavailable = validLines
        .where((line) => line.item.stock <= 0)
        .map((line) => line.item.name)
        .toList();
    if (unavailable.isNotEmpty) {
      setState(() {
        _error = 'Немає в наявності: ${unavailable.join(', ')}';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
      _completedOrder = null;
    });
    try {
      final result = await _service.submit(
        token: widget.token,
        lines: validLines,
        paymentForm: _paymentForm!,
        cashMethod: _paymentForm == 'cash' ? _cashMethod : '',
        comment: _commentCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        final accepted = result.number.isEmpty
            ? 'Замовлення прийнято'
            : 'Замовлення №${result.number} прийнято';
        _success = result.licenseWarning.isEmpty
            ? accepted
            : '$accepted. ${result.licenseWarning}';
        _completedOrder = result;
        _lines.clear();
        for (final ctrl in _qtyCtrls.values) {
          ctrl.dispose();
        }
        _qtyCtrls.clear();
      });
      unawaited(_loadHistory());
      if (_cartSheetOpen && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  double get _total => _lines.fold(0, (sum, line) => sum + line.amount);

  void _openCartSheet() {
    _cartSheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final cs = Theme.of(context).colorScheme;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: .76,
                minChildSize: .42,
                maxChildSize: .94,
                expand: false,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(26),
                      ),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: cs.outlineVariant,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _OrderPanel(
                          lines: _lines,
                          total: _total,
                          paymentOptions: _form?.paymentOptions ?? const [],
                          paymentForm: _paymentForm,
                          cashMethod: _cashMethod,
                          commentCtrl: _commentCtrl,
                          submitting: _submitting,
                          onPaymentFormChanged: (value) {
                            setState(() => _paymentForm = value);
                            setSheetState(() {});
                          },
                          onCashMethodChanged: (value) {
                            setState(() => _cashMethod = value);
                            setSheetState(() {});
                          },
                          onRemove: (uid) {
                            _removeLine(uid);
                            setSheetState(() {});
                          },
                          onQuantityChanged: (line, value) {
                            _setQuantity(line, value);
                            setSheetState(() {});
                          },
                          quantityController: _syncQtyCtrl,
                          onSubmit: _submit,
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    ).whenComplete(() => _cartSheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _publicOrderTheme(context);
    final cs = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 980;
    final mobileCart = width < 920;
    final hideMobileCart = mobileCart && _searchFocus.hasFocus;

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: mobileCart &&
                !_loading &&
                _form != null &&
                !hideMobileCart &&
                _completedOrder == null
            ? _MobileCartButton(
                linesCount: _lines.length,
                total: _total,
                onPressed: _openCartSheet,
              )
            : null,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_b2bBgTop, _b2bBg, _b2bBgBottom],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1540),
                child: ListView(
                  padding: EdgeInsets.all(desktop ? 28 : 16),
                  children: [
                    _Header(
                      form: _form,
                      items: _items,
                      linesCount: _lines.length,
                      total: _total,
                      historyCount: _history.length,
                      onCartPressed: mobileCart ? _openCartSheet : null,
                    ),
                    const SizedBox(height: 18),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_error != null && _form == null)
                      _StateCard(
                        icon: Icons.cloud_off_rounded,
                        title: 'Не вдалося відкрити форму',
                        text: _error!,
                        actionLabel: 'Спробувати ще раз',
                        onAction: _load,
                      )
                    else ...[
                      if (_error != null)
                        _MessageBanner(
                          text: _error!,
                          color: cs.errorContainer,
                          textColor: cs.onErrorContainer,
                        ),
                      if (_success != null)
                        if (_completedOrder == null)
                          _MessageBanner(
                            text: _success!,
                            color: cs.primaryContainer,
                            textColor: cs.onPrimaryContainer,
                          ),
                      if (_completedOrder != null)
                        _OrderCreatedCard(
                          result: _completedOrder!,
                          onNewOrder: () {
                            setState(() {
                              _completedOrder = null;
                              _success = null;
                            });
                          },
                        ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final twoColumns = constraints.maxWidth >= 1040;
                          final catalog = _CatalogPanel(
                            searchCtrl: _searchCtrl,
                            searchFocus: _searchFocus,
                            items: _items,
                            searching: _searching,
                            onSearchChanged: _scheduleSearch,
                            onRefresh: () => _search(_searchCtrl.text),
                            onAdd: (item) {
                              _addItem(item);
                            },
                          );
                          final promo = _PromotionsBlock(
                            items: _items,
                            onAdd: (item) => _addItem(item),
                          );
                          final workspace = _WorkspaceTabs(
                            selectedIndex: _selectedWorkspace,
                            onChanged: (value) {
                              setState(() => _selectedWorkspace = value);
                              if (value == 1 &&
                                  !_historyLoading &&
                                  _history.isEmpty) {
                                unawaited(_loadHistory());
                              }
                            },
                            catalog: catalog,
                            history: _HistoryPanel(
                              orders: _history,
                              loading: _historyLoading,
                              error: _historyError,
                              onRefresh: _loadHistory,
                            ),
                          );
                          final order = _OrderPanel(
                            lines: _lines,
                            total: _total,
                            paymentOptions: _form?.paymentOptions ?? const [],
                            paymentForm: _paymentForm,
                            cashMethod: _cashMethod,
                            commentCtrl: _commentCtrl,
                            submitting: _submitting,
                            onPaymentFormChanged: (value) {
                              setState(() => _paymentForm = value);
                            },
                            onCashMethodChanged: (value) {
                              setState(() => _cashMethod = value);
                            },
                            onRemove: _removeLine,
                            onQuantityChanged: _setQuantity,
                            quantityController: _syncQtyCtrl,
                            onSubmit: _submit,
                          );
                          if (!twoColumns) {
                            return Column(
                              children: [
                                promo,
                                const SizedBox(height: 12),
                                workspace,
                                const SizedBox(height: 92),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              promo,
                              const SizedBox(height: 18),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 8, child: workspace),
                                  const SizedBox(width: 18),
                                  SizedBox(width: 430, child: order),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.form,
    required this.items,
    required this.linesCount,
    required this.total,
    required this.historyCount,
    required this.onCartPressed,
  });

  final PublicOrderForm? form;
  final List<PublicOrderItem> items;
  final int linesCount;
  final double total;
  final int historyCount;
  final VoidCallback? onCartPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 760;
    final title =
        form?.partnerName.isNotEmpty == true ? form!.partnerName : 'MOVA B2B';
    final subtitle = form?.contractorName.isNotEmpty == true
        ? form!.contractorName
        : 'Персональний кабінет замовлення';
    final showcase = items.where((item) => item.stock > 0).take(4).toList();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _HeroChip(
                icon: Icons.verified_rounded, text: 'Персональна B2B-форма'),
            _HeroChip(
                icon: Icons.inventory_2_rounded, text: 'Актуальні залишки'),
          ],
        ),
        SizedBox(height: compact ? 18 : 18),
        Text(
          title,
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: (compact
                  ? theme.textTheme.headlineMedium
                  : theme.textTheme.displaySmall)
              ?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            height: 1.02,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: .78),
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _HeroMetric(
              icon: Icons.shopping_bag_rounded,
              label: 'У кошику',
              value: linesCount == 0 ? '0 поз.' : '$linesCount поз.',
            ),
            _HeroMetric(
              icon: Icons.payments_rounded,
              label: 'Сума',
              value: _formatMoney(total),
            ),
            _HeroMetric(
              icon: Icons.history_rounded,
              label: 'Історія',
              value: historyCount == 0 ? 'нова' : '$historyCount зам.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onCartPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _b2bInk,
              ),
              icon: const Icon(Icons.shopping_cart_checkout_rounded),
              label: const Text('Перейти до кошика'),
            ),
            if (form?.managerPhone.isNotEmpty == true)
              _HeroCallButton(phone: form!.managerPhone),
          ],
        ),
      ],
    );

    if (!compact) {
      return Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF083A36), Color(0xFF0F766E), Color(0xFF1D4ED8)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: .18),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _HeroChip(
                        icon: Icons.verified_rounded,
                        text: 'Персональна B2B-форма',
                      ),
                      _HeroChip(
                        icon: Icons.inventory_2_rounded,
                        text: 'Актуальні залишки',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.04,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: .78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              flex: 6,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroMetric(
                    icon: Icons.shopping_bag_rounded,
                    label: 'У кошику',
                    value: linesCount == 0 ? '0 поз.' : '$linesCount поз.',
                  ),
                  _HeroMetric(
                    icon: Icons.payments_rounded,
                    label: 'Сума',
                    value: _formatMoney(total),
                  ),
                  if (form?.managerPhone.isNotEmpty == true)
                    _HeroCallButton(phone: form!.managerPhone),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final visual = _HeroShowcase(
      items: showcase,
      managerName: form?.managerName ?? '',
      managerPhone: form?.managerPhone ?? '',
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF082F2D),
        borderRadius: BorderRadius.circular(compact ? 22 : 32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: .22),
            blurRadius: 38,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF083A36),
                    Color(0xFF0F766E),
                    Color(0xFF1D4ED8),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -90,
            top: -70,
            child: Transform.rotate(
              angle: -.22,
              child: Container(
                width: 260,
                height: 420,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(42),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 20 : 24),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [content, const SizedBox(height: 24), visual],
                  )
                : Row(
                    children: [
                      Expanded(flex: 6, child: content),
                      const SizedBox(width: 30),
                      Expanded(flex: 5, child: visual),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _b2bGold, size: 20),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .64),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCallButton extends StatelessWidget {
  const _HeroCallButton({required this.phone});

  final String phone;

  String get _normalizedPhone => phone
      .replaceAll(RegExp(r'[^0-9+]'), '')
      .replaceFirst(RegExp(r'^00'), '+');

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _normalizedPhone.isEmpty
          ? null
          : () => launchUrl(
                Uri(scheme: 'tel', path: _normalizedPhone),
                mode: LaunchMode.externalApplication,
              ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: .42)),
      ),
      icon: const Icon(Icons.call_rounded),
      label: const Text('Зв’язатися'),
    );
  }
}

class _HeroShowcase extends StatelessWidget {
  const _HeroShowcase({
    required this.items,
    required this.managerName,
    required this.managerPhone,
  });

  final List<PublicOrderItem> items;
  final String managerName;
  final String managerPhone;

  @override
  Widget build(BuildContext context) {
    final featured = items.isEmpty ? null : items.first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 8.8,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (featured != null && featured.imageUrl.isNotEmpty)
                    Image.network(
                      featured.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _HeroFallbackVisual(),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const _HeroFallbackVisual(),
                    )
                  else
                    const _HeroFallbackVisual(),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: .62),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          featured?.name ?? 'Швидке замовлення MOVA',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          featured == null
                              ? 'Каталог, акції та історія в одному кабінеті'
                              : 'В наявності: ${_formatNumber(featured.stock)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .78),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final item in items.take(3)) ...[
                Expanded(
                  child: _HeroMiniProduct(item: item),
                ),
                if (item != items.take(3).last) const SizedBox(width: 8),
              ],
              if (items.isEmpty)
                const Expanded(
                  child: _HeroFallbackCard(),
                ),
            ],
          ),
          if (managerName.isNotEmpty || managerPhone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      managerName.isEmpty ? managerPhone : managerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (managerPhone.isNotEmpty)
                    Text(
                      managerPhone,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMiniProduct extends StatelessWidget {
  const _HeroMiniProduct({required this.item});

  final PublicOrderItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductThumbnail(imageUrl: item.imageUrl, size: 42),
          const SizedBox(height: 7),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallbackVisual extends StatelessWidget {
  const _HeroFallbackVisual();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFECFEFF), Color(0xFFDDF7F3), Color(0xFFFFEDD5)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.local_drink_rounded, size: 78, color: _b2bAccent),
      ),
    );
  }
}

class _HeroFallbackCard extends StatelessWidget {
  const _HeroFallbackCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Каталог завантажується',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _PromotionsBlock extends StatelessWidget {
  const _PromotionsBlock({required this.items, required this.onAdd});

  final List<PublicOrderItem> items;
  final ValueChanged<PublicOrderItem> onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offers =
        items.where((item) => item.stock > 0).take(3).toList(growable: false);

    final heading = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.local_offer_outlined, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Акції',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Актуальні позиції для швидкого B2B-замовлення',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: .72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final badges = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        _PromoBadge(icon: Icons.verified_outlined, text: 'Наявність зі складу'),
        _PromoBadge(icon: Icons.inventory_2_outlined, text: 'Зручно ящиками'),
        _PromoBadge(
          icon: Icons.receipt_long_outlined,
          text: 'Рахунок після замовлення',
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_b2bAccent, _b2bBlue, _b2bCoral],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: _b2bShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1120;
          final offerWidgets = [
            for (final item in offers)
              _PromotionTile(
                item: item,
                onAdd: () => onAdd(item),
              ),
          ];
          final offersView = offers.isEmpty
              ? Text(
                  'Після оновлення каталогу тут з’являться доступні пропозиції.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: .78),
                    fontWeight: FontWeight.w700,
                  ),
                )
              : wide
                  ? Row(
                      children: [
                        for (final child in offerWidgets) ...[
                          Expanded(child: child),
                          if (child != offerWidgets.last)
                            const SizedBox(width: 10),
                        ],
                      ],
                    )
                  : Column(
                      children: [
                        for (final child in offerWidgets) ...[
                          child,
                          if (child != offerWidgets.last)
                            const SizedBox(height: 10),
                        ],
                      ],
                    );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: 14),
                offersView,
                const SizedBox(height: 12),
                badges,
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heading, const SizedBox(height: 12), badges],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: offersView),
            ],
          );
        },
      ),
    );
  }
}

class _PromotionTile extends StatelessWidget {
  const _PromotionTile({required this.item, required this.onAdd});

  final PublicOrderItem item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          _ProductThumbnail(imageUrl: item.imageUrl, size: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.boxQuantity > 0
                      ? 'Ящик: ${_formatNumber(item.boxQuantity)}'
                      : 'В наявності: ${_formatNumber(item.stock)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .70),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Додати',
            onPressed: onAdd,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _b2bAccent,
            ),
            icon: const Icon(Icons.add_shopping_cart_rounded),
          ),
        ],
      ),
    );
  }
}

class _PromoBadge extends StatelessWidget {
  const _PromoBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: .86)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .86),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceTabs extends StatelessWidget {
  const _WorkspaceTabs({
    required this.selectedIndex,
    required this.onChanged,
    required this.catalog,
    required this.history,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Widget catalog;
  final Widget history;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<int>(
                value: 0,
                icon: Icon(Icons.storefront_outlined),
                label: Text('Каталог'),
              ),
              ButtonSegment<int>(
                value: 1,
                icon: Icon(Icons.history_rounded),
                label: Text('Історія'),
              ),
            ],
            selected: {selectedIndex},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) onChanged(selection.first);
            },
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(selectedIndex),
            child: selectedIndex == 0 ? catalog : history,
          ),
        ),
      ],
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.orders,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final List<PublicOrderHistoryOrder> orders;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Історія замовлень',
      trailing: IconButton(
        tooltip: 'Оновити',
        onPressed: loading ? null : onRefresh,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded),
      ),
      child: Column(
        children: [
          if (error != null)
            _MessageBanner(
              text: error!,
              color: Theme.of(context).colorScheme.errorContainer,
              textColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
          if (loading && orders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(34),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (orders.isEmpty)
            const _EmptyText('Попередніх замовлень ще немає')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _HistoryOrderRow(
                order: orders[index],
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryOrderRow extends StatelessWidget {
  const _HistoryOrderRow({required this.order});

  final PublicOrderHistoryOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final number = order.number.isEmpty ? 'Без номера' : '№ ${order.number}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.receipt_long_rounded, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      _formatDate(order.date),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _b2bMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (order.shipmentDate != null)
                      Text(
                        'Відвантаження: ${_formatDate(order.shipmentDate)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _b2bMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (order.status.isNotEmpty)
                      Text(
                        order.status,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatMoney(order.amount),
                style: TextStyle(
                  color: cs.secondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                order.linesCount == 0 ? '' : '${order.linesCount} поз.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _b2bMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogPanel extends StatelessWidget {
  const _CatalogPanel({
    required this.searchCtrl,
    required this.searchFocus,
    required this.items,
    required this.searching,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onAdd,
  });

  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final List<PublicOrderItem> items;
  final bool searching;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final ValueChanged<PublicOrderItem> onAdd;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Каталог',
      subtitle: 'Обирайте позиції, перевіряйте залишки та додавайте в кошик',
      trailing: IconButton.filledTonal(
        tooltip: 'Оновити',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchCtrl,
            focusNode: searchFocus,
            decoration: InputDecoration(
              hintText: 'Пошук за назвою або кодом',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Шукати',
                      onPressed: onRefresh,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
            ),
            onChanged: onSearchChanged,
            onSubmitted: (_) => onRefresh(),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const _EmptyText('Номенклатуру не знайдено')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 560) {
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _CatalogMobileRow(
                      item: items[index],
                      onAdd: () => onAdd(items[index]),
                    ),
                  );
                }
                final columns = constraints.maxWidth >= 900 ? 3 : 2;
                const gap = 12.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: width,
                        child: _CatalogCard(
                          item: item,
                          onAdd: () => onAdd(item),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item, required this.onAdd});

  final PublicOrderItem item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final available = item.stock > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: available ? onAdd : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _b2bLine),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: .06),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProductImageFill(imageUrl: item.imageUrl),
                    Positioned(
                      left: 10,
                      top: 10,
                      child:
                          _StockBadge(available: available, stock: item.stock),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatMoneyShort(item.price),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.secondary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.boxQuantity > 0
                                    ? 'Ящик ${_formatNumber(item.boxQuantity)}'
                                    : 'Поштучно',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _b2bMuted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filled(
                          tooltip:
                              available ? 'Додати товар' : 'Немає в наявності',
                          onPressed: available ? onAdd : null,
                          style: IconButton.styleFrom(
                            backgroundColor: available ? _b2bAccent : _b2bLine,
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(
                            available
                                ? Icons.add_shopping_cart_rounded
                                : Icons.block_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImageFill extends StatelessWidget {
  const _ProductImageFill({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = const _ProductImageFallback();
    if (imageUrl.isEmpty) return fallback;
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDFA), Color(0xFFEFF6FF), Color(0xFFFFF7ED)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.inventory_2_outlined, size: 58, color: _b2bAccent),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.available, required this.stock});

  final bool available;
  final double stock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: available ? _b2bAccent : _b2bDanger,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        available ? 'В наявності ${_formatNumber(stock)}' : 'Немає',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _CatalogMobileRow extends StatelessWidget {
  const _CatalogMobileRow({required this.item, required this.onAdd});

  final PublicOrderItem item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final available = item.stock > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProductThumbnail(imageUrl: item.imageUrl, size: 52),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _CatalogMobileMetric(
                      label: 'Залишок',
                      value: _formatNumber(item.stock),
                      color: item.stock > 0 ? cs.primary : cs.error,
                    ),
                    _CatalogMobileMetric(
                      label: 'Ціна',
                      value: _formatMoneyShort(item.price),
                      color: cs.secondary,
                    ),
                    _CatalogMobileMetric(
                      label: 'Ящик',
                      value: item.boxQuantity > 0
                          ? _formatNumber(item.boxQuantity)
                          : '-',
                      color: cs.tertiary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: available ? 'Додати товар' : 'Немає в наявності',
                onPressed: available ? onAdd : null,
                icon: Icon(
                  available
                      ? Icons.add_shopping_cart_rounded
                      : Icons.block_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({
    required this.imageUrl,
    required this.size,
  });

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: size * .42,
        color: cs.onSurfaceVariant.withValues(alpha: .55),
      ),
    );

    if (imageUrl.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
      ),
    );
  }
}

class _CatalogMobileMetric extends StatelessWidget {
  const _CatalogMobileMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _MobileCartButton extends StatelessWidget {
  const _MobileCartButton({
    required this.linesCount,
    required this.total,
    required this.onPressed,
  });

  final int linesCount;
  final double total;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 12,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: .24),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_bag_rounded,
                  color: cs.onPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    linesCount == 0
                        ? 'Кошик порожній'
                        : 'У кошику: $linesCount',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  _formatMoney(total),
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w900,
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

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({
    required this.lines,
    required this.total,
    required this.paymentOptions,
    required this.paymentForm,
    required this.cashMethod,
    required this.commentCtrl,
    required this.submitting,
    required this.onPaymentFormChanged,
    required this.onCashMethodChanged,
    required this.onRemove,
    required this.onQuantityChanged,
    required this.quantityController,
    required this.onSubmit,
  });

  final List<PublicOrderLine> lines;
  final double total;
  final List<PublicOrderPaymentOption> paymentOptions;
  final String? paymentForm;
  final String cashMethod;
  final TextEditingController commentCtrl;
  final bool submitting;
  final ValueChanged<String> onPaymentFormChanged;
  final ValueChanged<String> onCashMethodChanged;
  final ValueChanged<String> onRemove;
  final void Function(PublicOrderLine line, String value) onQuantityChanged;
  final TextEditingController Function(String uid) quantityController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Замовлення',
      trailing: Text(
        _formatMoney(total),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
      child: Column(
        children: [
          if (lines.isEmpty)
            const _EmptyText('Додайте товари з каталогу')
          else
            for (final line in lines)
              _OrderLineRow(
                line: line,
                controller: quantityController(line.item.uid),
                onChanged: (value) => onQuantityChanged(line, value),
                onRemove: () => onRemove(line.item.uid),
              ),
          const SizedBox(height: 12),
          _PaymentSelector(
            options: paymentOptions,
            paymentForm: paymentForm,
            cashMethod: cashMethod,
            onPaymentFormChanged: onPaymentFormChanged,
            onCashMethodChanged: onCashMethodChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: commentCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Коментар до замовлення',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(submitting ? 'Відправляємо...' : 'Замовити'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSelector extends StatelessWidget {
  const _PaymentSelector({
    required this.options,
    required this.paymentForm,
    required this.cashMethod,
    required this.onPaymentFormChanged,
    required this.onCashMethodChanged,
  });

  final List<PublicOrderPaymentOption> options;
  final String? paymentForm;
  final String cashMethod;
  final ValueChanged<String> onPaymentFormChanged;
  final ValueChanged<String> onCashMethodChanged;

  @override
  Widget build(BuildContext context) {
    PublicOrderPaymentOption? selectedOption;
    for (final option in options) {
      if (option.code == paymentForm) {
        selectedOption = option;
        break;
      }
    }
    if (options.isEmpty) {
      return Text(
        'Для партнера не налаштовані договори оплати',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Оплата',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            emptySelectionAllowed: options.length > 1,
            showSelectedIcon: true,
            segments: [
              for (final option in options)
                ButtonSegment<String>(
                  value: option.code,
                  icon: Icon(
                    option.isCash
                        ? Icons.payments_outlined
                        : Icons.account_balance_outlined,
                  ),
                  label: Text(option.title),
                ),
            ],
            selected: paymentForm == null ? const {} : {paymentForm!},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                onPaymentFormChanged(selection.first);
              }
            },
          ),
        ),
        if (selectedOption?.isCash == true) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: true,
              segments: const [
                ButtonSegment<String>(
                  value: 'fact',
                  icon: Icon(Icons.payments_rounded),
                  label: Text('Факт'),
                ),
                ButtonSegment<String>(
                  value: 'card',
                  icon: Icon(Icons.credit_card_rounded),
                  label: Text('На картку'),
                ),
              ],
              selected: {cashMethod},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  onCashMethodChanged(selection.first);
                }
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _OrderLineRow extends StatelessWidget {
  const _OrderLineRow({
    required this.line,
    required this.controller,
    required this.onChanged,
    required this.onRemove,
  });

  final PublicOrderLine line;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatMoney(line.item.price)} x ${_formatNumber(line.quantity)} = ${_formatMoney(line.amount)}',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: .68),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'К-сть'),
              onChanged: onChanged,
            ),
          ),
          IconButton(
            tooltip: 'Прибрати',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: .06),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _b2bMuted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _OrderCreatedCard extends StatelessWidget {
  const _OrderCreatedCard({
    required this.result,
    required this.onNewOrder,
  });

  final PublicOrderSubmitResult result;
  final VoidCallback onNewOrder;

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: .4)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 660;
          final info = Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.check_rounded, color: cs.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Замовлення створено',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      result.number.isEmpty
                          ? 'Ми вже отримали ваше замовлення'
                          : '№ ${result.number}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (result.licenseWarning.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.licenseWarning,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.tertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (result.paymentAvailable && result.paymentUrl.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => _open(result.paymentUrl),
                  icon: const Icon(Icons.account_balance_wallet_rounded),
                  label: const Text('Оплатити'),
                ),
              OutlinedButton.icon(
                onPressed: result.invoiceUrl.isEmpty
                    ? null
                    : () => _open(result.invoiceUrl),
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Отримати рахунок'),
              ),
              TextButton.icon(
                onPressed: onNewOrder,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Нове замовлення'),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 16),
                actions,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: .76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 54, color: cs.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: .6),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return '-';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

String _formatMoney(double value) => '${_formatNumber(value)} UAH';

String _formatMoneyShort(double value) => _formatNumber(value);

String _formatNumber(double value) {
  final text = value
      .toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)
      .replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]} ',
      );
  return text;
}

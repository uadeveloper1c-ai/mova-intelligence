// lib/features/home/presentation/home_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../approvals/domain/payment_request.dart';
import '../../approvals/approvals_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  String? _error;

  int _incomingPending = 0; // На погодженні (я як погоджуючий)
  int _myPending = 0; // Мої заявки в статусі Pending
  int _myToPaid = 0; // Мої заявки в статусі ToPaid

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final approvals = context.read<ApprovalsService>();

      final incoming = await approvals.getIncomingRequests();
      final my = await approvals.getMyRequests();

      if (!mounted) return;
      setState(() {
        _incomingPending =
            incoming.where((r) => r.status == PaymentRequestStatus.pending).length;

        _myPending = my.where((r) => r.status == PaymentRequestStatus.pending).length;

        _myToPaid = my.where((r) => r.status == PaymentRequestStatus.topaid).length;

        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const panel = Color(0xFF0B1220);
    const border = Color(0xFF111827);
    const text = Color(0xFFE5E7EB);
    const sub = Color(0xFF9CA3AF);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Помилка завантаження: $_error', style: const TextStyle(color: text)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        children: [
          const Text(
            'MOVA фінанси',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Короткий огляд ваших заявок та оплат.',
            style: TextStyle(fontSize: 13, color: sub, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // ===== 1 карточка: Заявки =====
          _SectionCard(
            title: 'Заявки',
            subtitle: 'Статуси та лічильники',
            onTap: () {
              // TODO: открыть экран заявок
              // context.go('/approvals');
            },
            child: Column(
              children: [
                _StatusRow(
                  title: 'На погодженні',
                  subtitle: 'Очікують вашого рішення',
                  value: _incomingPending,
                  pillColor: const Color(0xFFF59E0B), // amber
                  icon: Icons.verified_outlined,
                  onTap: () {
                    // context.go('/approvals');
                  },
                ),
                const SizedBox(height: 10),
                _StatusRow(
                  title: 'Мої заявки',
                  subtitle: 'Статус: На погодженні',
                  value: _myPending,
                  pillColor: const Color(0xFF38BDF8), // sky
                  icon: Icons.assignment_outlined,
                  onTap: () {
                    // context.go('/approvals');
                  },
                ),
                const SizedBox(height: 10),
                _StatusRow(
                  title: 'До оплати',
                  subtitle: 'Погоджені, чекають оплати',
                  value: _myToPaid,
                  pillColor: const Color(0xFFA78BFA), // purple
                  icon: Icons.payments_outlined,
                  onTap: () {
                    // context.go('/approvals');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ===== 2 карточка: Звіти =====
          _SectionCard(
            title: 'Звіти',
            subtitle: 'Скоро буде доступно',
            onTap: () {
              // TODO: reports
            },
            child: Row(
              children: [
                _SoftIcon(
                  icon: Icons.bar_chart_outlined,
                  color: const Color(0xFF22C55E),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Поки що тут буде коротка аналітика оплат і заявок.\nЗараз — заглушка.',
                    style: TextStyle(color: sub, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: panel.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: border),
                  ),
                  child: const Text(
                    '0',
                    style: TextStyle(color: text, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onTap;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const panel = Color(0xFF0B1220);
    const border = Color(0xFF111827);
    const text = Color(0xFFE5E7EB);
    const sub = Color(0xFF9CA3AF);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: panel.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: sub),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: sub,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final int value;
  final Color pillColor;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatusRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.pillColor,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFF111827);
    const text = Color(0xFFE5E7EB);
    const sub = Color(0xFF9CA3AF);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border.withValues(alpha: 0.85)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              _SoftIcon(icon: icon, color: pillColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CountPill(value: value, color: pillColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SoftIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFF111827);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int value;
  final Color color;

  const _CountPill({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFF111827);
    const text = Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        value.toString(),
        style: TextStyle(
          color: (color.computeLuminance() < 0.45) ? color : text,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

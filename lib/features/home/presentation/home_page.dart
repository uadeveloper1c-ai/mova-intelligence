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
  int _myPending = 0;       // Мої заявки в статусі Pending
  int _myToPaid = 0;        // Мої заявки в статусі ToPaid (КОплате)

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

      setState(() {
        _incomingPending = incoming
            .where((r) => r.status == PaymentRequestStatus.pending)
            .length;

        _myPending = my
            .where((r) => r.status == PaymentRequestStatus.pending)
            .length;

        _myToPaid = my
            .where((r) => r.status == PaymentRequestStatus.topaid)
            .length;

        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Помилка завантаження: $_error'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'MOVA фінанси',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Короткий огляд ваших заявок та оплат.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),

          // 🔹 Светлые плитки 2×2
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.8, // ниже плитки, не такие высокие
            children: [
              _DashboardTile(
                title: 'На погодженні',
                value: _incomingPending.toString(),
                subtitle: 'Очікують вашого рішення',
                icon: Icons.verified_outlined,
                color: Colors.orange,
                onTap: () {
                  // context.go('/approvals');
                },
              ),
              _DashboardTile(
                title: 'Мої заявки',
                value: _myPending.toString(),
                subtitle: 'Статус: На погодженні',
                icon: Icons.assignment_outlined,
                color: Colors.blue,
                onTap: () {
                  // context.go('/approvals');
                },
              ),
              _DashboardTile(
                title: 'До оплати',
                value: _myToPaid.toString(),
                subtitle: 'Погоджені, чекають оплати',
                icon: Icons.payments_outlined,
                color: Colors.purple,
                onTap: () {
                  // context.go('/approvals');
                },
              ),
              _DashboardTile(
                title: 'Звіти',
                value: '0',
                subtitle: 'Скоро буде доступно',
                icon: Icons.bar_chart_outlined,
                color: Colors.green,
                onTap: () {
                  // TODO: звіти, коли зʼявляться
                },
              ),
            ],
          ),

          const SizedBox(height: 24),
          // ниже уже можно добавлять блоки "Мої заявки", "На погодженні" и т.п.
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _DashboardTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96), // светлая плитка
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // иконка в круге, как маленький бейдж
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
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

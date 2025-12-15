import 'package:flutter/material.dart';
import 'package:mova_intelligence_app/features/auth/session_store.dart';

/// Маленький плавающий виджет в углу экрана,
/// показывает текущего пользователя (ФИО) и признак утверждения платежей.
class DebugUserBadge extends StatefulWidget {
  const DebugUserBadge({super.key});

  @override
  State<DebugUserBadge> createState() => _DebugUserBadgeState();
}

class _DebugUserBadgeState extends State<DebugUserBadge> {
  SessionData? _session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await SessionStore.loadSession();
    setState(() => _session = s);
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) return const SizedBox.shrink();

    final canApprove = _session!.canApprovePayments;
    final text =
        '${_session!.fullName}${canApprove ? " ✅" : ""}'; // например: "Юра Ш. ✅"

    return Positioned(
      right: 12,
      bottom: 12,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

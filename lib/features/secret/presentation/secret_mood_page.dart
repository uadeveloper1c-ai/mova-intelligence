import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SecretMoodPage extends StatefulWidget {
  const SecretMoodPage({super.key, this.recipient = ''});

  final String recipient;

  @override
  State<SecretMoodPage> createState() => _SecretMoodPageState();
}

class _SecretMoodPageState extends State<SecretMoodPage> {
  static const _messages = <_MoodMessage>[
    _MoodMessage(
      'Ти справляєшся краще, ніж тобі здається.',
      'Не все важливе виглядає як великий результат. Іноді це просто день, у якому ти не здався.',
      'Сьогодні достатньо зробити наступний добрий крок.',
      Icons.auto_awesome_rounded,
      Color(0xFF1F9D8B),
    ),
    _MoodMessage(
      'Нагадування: ти не зобов’язаний бути продуктивним щохвилини.',
      'Пауза не відкидає назад. Вона повертає тобі увагу, сили й трохи простору всередині.',
      'Видихни повільніше, ніж вдихаєш.',
      Icons.air_rounded,
      Color(0xFF3985C6),
    ),
    _MoodMessage(
      'У цього дня ще є шанс приємно тебе здивувати.',
      'Навіть якщо ранок був не дуже, він не має права голосувати за весь день.',
      'Залиш трохи місця для хорошого.',
      Icons.wb_sunny_outlined,
      Color(0xFFE29B29),
    ),
    _MoodMessage(
      'Хтось точно радий, що ти є.',
      'Можливо, тобі про це говорять недостатньо часто. Але твоя присутність у чиємусь житті вже багато змінила.',
      'Напиши людині, про яку щойно подумав.',
      Icons.favorite_border_rounded,
      Color(0xFFD25B78),
    ),
    _MoodMessage(
      'Не всі перемоги шумні.',
      'Вчасно сказане «ні», завершена дрібниця, чесна розмова або ранній сон теж рахуються.',
      'Зарахуй собі хоча б одну перемогу сьогодні.',
      Icons.emoji_events_outlined,
      Color(0xFF8B69C8),
    ),
    _MoodMessage(
      'Ти маєш право рухатися у власному темпі.',
      'Порівнювати свій шлях із чужою вітриною — дуже неточна математика.',
      'Подивись не вбік, а на те, скільки вже пройдено.',
      Icons.route_rounded,
      Color(0xFF2C8B72),
    ),
    _MoodMessage(
      'Складний день не означає складне життя.',
      'Сьогоднішня втома говорить лише про сьогодні. Не дозволяй їй писати прогнози на майбутнє.',
      'Відклади один необов’язковий тягар.',
      Icons.nightlight_outlined,
      Color(0xFF5F78B8),
    ),
    _MoodMessage(
      'Твоя цікавість — це вже маленький двигун.',
      'Поки тобі хочеться питати, пробувати й помічати нове, попереду точно є цікаві повороти.',
      'Дізнайся сьогодні одну річ просто для себе.',
      Icons.lightbulb_outline_rounded,
      Color(0xFFE07B39),
    ),
    _MoodMessage(
      'З тобою не потрібно бути ідеальним.',
      'Достатньо бути живим, чесним і час від часу сміятися з того, що пішло зовсім не за планом.',
      'Дозволь собі сьогодні трохи недосконалості.',
      Icons.sentiment_satisfied_alt_rounded,
      Color(0xFFBA5B9F),
    ),
    _MoodMessage(
      'Майбутній ти вже вдячний тобі за деякі сьогоднішні рішення.',
      'Навіть маленькі турботливі дії накопичуються: вода, сон, дзвінок, завершена справа, спокійна відповідь.',
      'Зроби одну дрібницю для себе завтрашнього.',
      Icons.schedule_rounded,
      Color(0xFF278F9D),
    ),
    _MoodMessage(
      'Ти не запізнився.',
      'Не існує єдиного правильного розкладу для змін, радості, нової справи чи нового початку.',
      'Почати можна навіть із двох хвилин.',
      Icons.play_circle_outline_rounded,
      Color(0xFF6B8F3D),
    ),
    _MoodMessage(
      'Світ не став гіршим від того, що ти сьогодні втомився.',
      'Тобі не треба заслужити відпочинок. Ти вже людина, а не нескінченний список завдань.',
      'Зроби щось повільно й без користі.',
      Icons.local_cafe_outlined,
      Color(0xFFAD7150),
    ),
  ];

  late final Random _random;
  late _MoodMessage _message;
  int _messageKey = 0;

  @override
  void initState() {
    super.initState();
    _random = Random(DateTime.now().microsecondsSinceEpoch);
    _message = _messages[_random.nextInt(_messages.length)];
  }

  void _next() {
    var next = _message;
    while (next == _message) {
      next = _messages[_random.nextInt(_messages.length)];
    }
    setState(() {
      _message = next;
      _messageKey++;
    });
  }

  Future<void> _copy() async {
    final name = widget.recipient.trim();
    final prefix = name.isEmpty ? '' : '$name, ';
    await Clipboard.setData(
      ClipboardData(
        text: '$prefix${_message.title}\n\n${_message.body}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Послання скопійовано')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.recipient.trim();
    final greeting = name.isEmpty ? 'Це тобі' : '$name, це тобі';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F6),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PatternPainter(color: _message.accent),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, .04),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      key: ValueKey(_messageKey),
                      padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _message.accent.withValues(alpha: .28),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A173A35),
                            blurRadius: 32,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _message.accent.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _message.icon,
                                  color: _message.accent,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      greeting,
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        color: _message.accent,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'секретне повідомлення від MOVA',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFF71807D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Скопіювати',
                                onPressed: _copy,
                                icon: const Icon(Icons.copy_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 42),
                          Text(
                            _message.title,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: const Color(0xFF172824),
                              fontWeight: FontWeight.w900,
                              height: 1.14,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _message.body,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF4E5E5A),
                              fontWeight: FontWeight.w500,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 36),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _message.accent.withValues(alpha: .08),
                              border: Border(
                                left: BorderSide(
                                  color: _message.accent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(
                              _message.smallStep,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFF263D37),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _next,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _message.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Ще одне'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'Посилання можна відкривати скільки завгодно разів',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF81908D),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const gap = 42.0;
    for (double x = -gap; x < size.width + gap; x += gap) {
      for (double y = -gap; y < size.height + gap; y += gap) {
        final alternate = ((x / gap).round() + (y / gap).round()).isEven;
        if (alternate) {
          canvas.drawCircle(Offset(x, y), 3.5, paint);
        } else {
          canvas.drawLine(
            Offset(x - 4, y),
            Offset(x + 4, y),
            paint,
          );
          canvas.drawLine(
            Offset(x, y - 4),
            Offset(x, y + 4),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MoodMessage {
  const _MoodMessage(
    this.title,
    this.body,
    this.smallStep,
    this.icon,
    this.accent,
  );

  final String title;
  final String body;
  final String smallStep;
  final IconData icon;
  final Color accent;
}

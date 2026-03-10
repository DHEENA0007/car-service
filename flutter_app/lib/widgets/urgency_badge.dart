import 'package:flutter/material.dart';
import '../utils/theme.dart';

class UrgencyBadge extends StatelessWidget {
  final String urgency;
  final bool large;

  const UrgencyBadge({super.key, required this.urgency, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getUrgencyColor(urgency);
    final label = urgency.toUpperCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 10,
        vertical: large ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: large ? 14 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

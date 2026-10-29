import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Color scoreColor(int score) {
  if (score >= 75) return AppColors.success;
  if (score >= 50) return AppColors.primary;
  if (score >= 35) return AppColors.warning;
  return AppColors.danger;
}

/// Circular compatibility badge (0-100%).
class ScoreRing extends StatelessWidget {
  final int score;
  final double size;
  const ScoreRing(this.score, {super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(score);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score / 100),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: size * 0.09,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Center(
            child: Text('$score%',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: size * 0.26)),
          ),
        ],
      ),
    );
  }
}

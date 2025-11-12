import 'package:flutter/material.dart';

class Loader extends StatelessWidget {
  final double size;
  final bool showCaption;
  final String caption;

  const Loader({
    super.key,
    this.size = 22,
    this.showCaption = false,
    this.caption = 'MEGG',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 1.2,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
          ),
        ),
        if (showCaption) ...[
          const SizedBox(height: 14),
          Text(
            caption,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 6,
              color: Colors.black,
            ),
          ),
        ],
      ],
    );
  }
}

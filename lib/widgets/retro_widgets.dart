import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Retro Panel ─────────────────────────────────────────────────────────────
class RetroPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsets? padding;
  final Color borderColor;

  const RetroPanel({
    super.key,
    required this.title,
    required this.child,
    this.padding,
    this.borderColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              '[ $title ]',
              style: GoogleFonts.spaceMono(
                color: borderColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Container(height: 1, color: borderColor),
          Padding(
            padding: padding ?? const EdgeInsets.all(10),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─── Retro Button ─────────────────────────────────────────────────────────────
class RetroButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final double fontSize;

  const RetroButton({
    super.key,
    required this.label,
    this.onTap,
    this.color,
    this.fontSize = 11,
  });

  @override
  State<RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<RetroButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? Colors.white;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _pressed ? c : Colors.black,
          border: Border.all(color: c, width: 1.5),
        ),
        child: Text(
          widget.label,
          style: GoogleFonts.spaceMono(
            color: _pressed ? Colors.black : c,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ─── Mono Text ────────────────────────────────────────────────────────────────
class MonoText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final double? letterSpacing;
  final TextAlign? textAlign;

  const MonoText(
    this.text, {
    super.key,
    this.fontSize = 12,
    this.color = Colors.white,
    this.fontWeight = FontWeight.normal,
    this.letterSpacing,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: GoogleFonts.spaceMono(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      ),
    );
  }
}

// ─── Retro Divider ────────────────────────────────────────────────────────────
class RetroDivider extends StatelessWidget {
  final String? label;
  const RetroDivider({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Container(margin: const EdgeInsets.symmetric(vertical: 8), height: 1, color: Colors.white30);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: Colors.white30)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: MonoText(label!, fontSize: 9, color: Colors.white54),
          ),
          Expanded(child: Container(height: 1, color: Colors.white30)),
        ],
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const StatusBadge(this.text, {super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: GoogleFonts.spaceMono(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ─── Retro Slider ─────────────────────────────────────────────────────────────
class RetroSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const RetroSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
        thumbShape: const RectangularSliderThumbShape(),
        trackHeight: 3,
        overlayColor: Colors.transparent,
      ),
      child: Slider(value: value, min: min, max: max, onChanged: onChanged),
    );
  }
}

class RectangularSliderThumbShape extends SliderComponentShape {
  const RectangularSliderThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(10, 18);

  @override
  void paint(PaintingContext context, Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final paint = Paint()..color = sliderTheme.thumbColor ?? Colors.white;
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 10, height: 20),
      paint,
    );
  }
}

// ─── Screen wrapper with scrolling ────────────────────────────────────────────
class RetroScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const RetroScreen({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MonoText(
                '> EXECUTING: ${title}_MODULE.exe',
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
            ...children,
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

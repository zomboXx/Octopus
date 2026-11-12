import 'package:flutter/material.dart';

const flowBlue = Color(0xff2463eb);
const flowInk = Color(0xff162139);
const flowMuted = Color(0xff73809a);
const flowCanvas = Color(0xfff5f5ff);
const flowLine = Color(0xffe9eafb);
const flowTint = Color(0xffeef1ff);

class OctopusLogo extends StatelessWidget {
  const OctopusLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/octopus-logo.png',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

class FlowCard extends StatelessWidget {
  const FlowCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: flowLine),
    ),
    child: child,
  );
}

class FlowTag extends StatelessWidget {
  const FlowTag(this.text, {super.key, this.filled = false, this.icon});
  final String text;
  final bool filled;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: filled ? flowBlue : flowTint,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: filled ? Colors.white : flowBlue),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: filled ? Colors.white : flowBlue,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
    ),
  );
}

class FlowAvatar extends StatelessWidget {
  const FlowAvatar(this.name, {super.key, this.size = 36, this.index = 0});
  final String name;
  final double size;
  final int index;
  @override
  Widget build(BuildContext context) {
    const shades = [
      Color(0xffdfe7ff),
      Color(0xffe4ddfa),
      Color(0xffdbf0ea),
      Color(0xffffe9d6),
    ];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: shades[index % shades.length],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        name.trim().isEmpty ? 'B' : name.trim().characters.first.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: flowInk,
          fontSize: size * .36,
        ),
      ),
    );
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'device_bridge.dart';
import 'flow_design.dart';

class AppIdentityIcon extends StatelessWidget {
  const AppIdentityIcon({
    super.key,
    required this.device,
    required this.package,
    required this.name,
    this.size = 40,
  });
  final DeviceBridge device;
  final String package, name;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<Uint8List?>(
        future: device.appIcon(package),
        builder: (_, snapshot) => snapshot.data != null
            ? Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    ),
  );
  Widget _fallback() => Container(
    decoration: BoxDecoration(
      color: flowTint,
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: Alignment.center,
    child: Text(
      name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
      style: const TextStyle(color: flowBlue, fontWeight: FontWeight.w700),
    ),
  );
}

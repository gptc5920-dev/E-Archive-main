import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path/path.dart' as p;

class AppAssetImage extends StatelessWidget {
  const AppAssetImage(
    this.assetPath, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.fallbackIcon = HugeIcons.strokeRoundedImageNotFound01,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      errorBuilder: (_, error, stackTrace) {
        return _FileFallbackAssetImage(
          assetPath: assetPath,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          fallbackIcon: fallbackIcon,
        );
      },
    );
  }
}

class _FileFallbackAssetImage extends StatelessWidget {
  const _FileFallbackAssetImage({
    required this.assetPath,
    required this.fallbackIcon,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final file = _firstExistingAssetFile();
    if (file != null) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, __, ___) => _fallbackBox(),
      );
    }
    return _fallbackBox();
  }

  File? _firstExistingAssetFile() {
    final executableDir = p.dirname(Platform.resolvedExecutable);
    final candidates = [
      p.join(executableDir, 'data', 'flutter_assets', assetPath),
      p.join(Directory.current.path, 'data', 'flutter_assets', assetPath),
      p.join(Directory.current.path, assetPath),
      p.join(p.dirname(Directory.current.path), assetPath),
    ];

    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync() && file.lengthSync() > 0) return file;
    }
    return null;
  }

  Widget _fallbackBox() {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          fallbackIcon,
          color: const Color(0xFF64748B),
          size: _fallbackIconSize,
        ),
      ),
    );
  }

  double get _fallbackIconSize {
    final shortest =
        [width, height].whereType<double>().fold<double?>(null, (value, item) {
      if (value == null) return item;
      return item < value ? item : value;
    });
    if (shortest == null) return 36;
    return (shortest * 0.42).clamp(18, 56).toDouble();
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:punto_neutro/core/image_cache_service.dart';
import 'package:punto_neutro/core/local_file_service.dart';

/// Widget de imagen que prioriza el cache en disco (LRU), y si no existe,
/// hace fallback a NetworkImage.
class CachedImage extends StatefulWidget {
  final String url;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? radius;

  const CachedImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.radius,
  });

  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  ImageProvider? _provider;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      // 1️⃣ Buscar si la URL ya está cacheada en Hive (vía ImageCacheService)
      final cachedName = await ImageCacheService.instance.getCachedNameForUrl(widget.url);

      if (cachedName != null && cachedName.isNotEmpty) {
        final file = await LocalFileService().getCacheFile(cachedName);
        if (await file.exists()) {
          setState(() {
            _provider = FileImage(file);
          });
          return;
        }
      }

      // 2️⃣ Si no hay cache válido, usa NetworkImage
      setState(() {
        _provider = NetworkImage(widget.url);
      });
    } catch (_) {
      setState(() {
        _provider = NetworkImage(widget.url);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _provider == null
        ? const ColoredBox(color: Color(0x11000000))
        : Image(
      image: _provider!,
      fit: widget.fit,
      height: widget.height,
      width: widget.width,
    );

    if (widget.radius != null) {
      return ClipRRect(
        borderRadius: widget.radius ?? BorderRadius.zero,
        child: child,
      );
    }
    return child;
  }
}

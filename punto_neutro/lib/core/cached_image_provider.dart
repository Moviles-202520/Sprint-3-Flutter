import 'dart:io';
import 'package:flutter/material.dart';

// Usa rutas de paquete para mantener consistencia con tu proyecto
import 'package:punto_neutro/core/image_cache_service.dart';
import 'package:punto_neutro/core/local_file_service.dart';

/// Obtiene un ImageProvider para una URL:
/// - Si está cacheada en disco (según índice Hive) → FileImage
/// - Si no, fallback → NetworkImage
class CachedImageProvider {
  /// Devuelve un ImageProvider listo para usar en Image(image: ...)
  static Future<ImageProvider> forUrl(String url) async {
    try {
      // 1) Busca en el índice LRU (Hive) el nombre físico del archivo cacheado.
      final name = await ImageCacheService.instance.getCachedNameForUrl(url);

      if (name != null && name.isNotEmpty) {
        // 2) Resuelve el File real y verifica que exista.
        final file = await LocalFileService().getCacheFile(name);
        if (await file!.exists()) {
          return FileImage(file);
        }
      }

      // 3) Fallback a red si no hay cache válida.
      return NetworkImage(url);
    } catch (_) {
      // Best-effort: ante cualquier error, usa la red.
      return NetworkImage(url);
    }
  }

  /// Atajo útil por si en algún punto quieres consultar si está cacheada.
  static Future<bool> isCached(String url) async {
    final name = await ImageCacheService.instance.getCachedNameForUrl(url);
    if (name == null || name.isEmpty) return false;
    final file = await LocalFileService().getCacheFile(name);
    return file.exists();
  }
}

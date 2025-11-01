import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:punto_neutro/data/repositories/sqlite_news_repository.dart';
import 'package:punto_neutro/data/repositories/supabase_auth_repository.dart';
import 'package:punto_neutro/data/repositories/supabase_news_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../../domain/repositories/news_repository.dart';
import '../../domain/models/news_item.dart';
import '../../domain/models/rating_item.dart';
import '../../domain/models/comment.dart';
import 'auth_repository.dart';

class HybridNewsRepository implements NewsRepository {
  /// Obtiene la lista de noticias (cache-first)
  @override
  Future<List<NewsItem>> getNewsList() async {
    final cacheKey = 'all_news';
    // 1. Intentar leer del cache
    final cachedList = _newsCache.get(cacheKey);
    if (cachedList != null && cachedList is List) {
      print('📱 Usando lista de noticias desde cache (${cachedList.length})');
      return cachedList.map<NewsItem>((item) => _mapToNewsItem(Map<String, dynamic>.from(item))).toList();
    }
    // 2. Si hay conexión, cargar de Supabase
    if (await _isConnected) {
      print('🌐 Cargando lista de noticias desde Supabase...');
      final response = await _supabase
          .from('news_items')
          .select()
          .order('publication_date', ascending: false)
          .limit(20)
          .timeout(const Duration(seconds: 10));
      final newsList = response.map((item) => Map<String, dynamic>.from(item)).toList();
      await _newsCache.put(cacheKey, newsList);
      return newsList.map<NewsItem>(_mapToNewsItem).toList();
    }
    // 3. Sin conexión y sin cache
    print('📴 Sin conexión y sin cache de lista de noticias');
    return [];
  }
  final SupabaseClient _supabase = Supabase.instance.client;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  
  // ✅ CAJAS CON TIPOS CORRECTOS
  Box<dynamic> get _newsCache => Hive.box<dynamic>('news_cache');
  Box<dynamic> get _commentsCache => Hive.box<dynamic>('comments_cache');
  Box<dynamic> get _ratingsCache => Hive.box<dynamic>('ratings_cache');

  // ✅ VERIFICAR CONEXIÓN
  Future<bool> get _isConnected async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Constructor: empezar a escuchar cambios de conectividad para sincronizar pendientes
  HybridNewsRepository({
    SqliteNewsRepository? sqlite,
    SupabaseNewsRepository? remote,
    AuthRepository? auth,
  }) {
    // Usa los que te pasen o crea/obtén los “default”
    // Ajusta a los constructores reales de tus clases (instance / default ctor).
    this.sqlite = sqlite ?? SqliteNewsRepository();            // o SqliteNewsRepository.instance
    this.remote = remote ?? SupabaseNewsRepository();          // o SupabaseNewsRepository.instance
    this.auth   = auth   ?? SupabaseAuthRepository();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) async {
      final isConnected = result != ConnectivityResult.none;
      if (isConnected) {
        try {
          print('📶 Conexión detectada — sincronizando datos pendientes');
          await syncPendingData();
        } catch (e) {
          print('⚠️ Error sincronizando al volver la conexión: $e');
        }
      }
    });

    // Intentar sincronizar al iniciar si ya hay conexión
    () async {
      if (await _isConnected) {
        await syncPendingData();
      }
    }();
  }

  @override
  Future<NewsItem?> getNewsDetail(String news_item_id) async {
    try {
        print('🔍 Buscando noticia: $news_item_id');
      
        // 1. Intentar leer del cache
      final cachedNews = _newsCache.get(news_item_id);
      if (cachedNews != null) {
        print('📱 Usando noticia desde cache: $news_item_id');
          try {
            final newsItem = _mapToNewsItem(Map<String, dynamic>.from(cachedNews));
            print('✅ Noticia mapeada correctamente desde cache');
            return newsItem;
          } catch (e) {
            print('❌ Error mapeando noticia desde cache: $e');
            // Si falla el mapeo, intentar cargar de Supabase
          }
        } else {
          print('⚠️ No hay cache para noticia: $news_item_id');
          // 🔎 Intentar obtener desde la lista en cache ('all_news')
          final cachedList = _newsCache.get('all_news');
          if (cachedList is List) {
            try {
              final match = cachedList
                  .cast<dynamic>()
                  .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
                  .firstWhere(
                    (e) => (e['news_item_id']?.toString() ?? '') == news_item_id,
                    orElse: () => {},
                  );
              if (match.isNotEmpty) {
                print('📚 Usando noticia desde lista cacheada (all_news)');
                // Cachear para acceso directo la próxima vez
                await _newsCache.put(news_item_id, match);
                return _mapToNewsItem(match);
              } else {
                print('🔎 No se encontró la noticia en la lista cacheada');
              }
            } catch (e) {
              print('⚠️ Error leyendo lista cacheada: $e');
            }
          } else {
            // Opcional: listar algunas claves para diagnóstico
            try {
              final keys = _newsCache.keys.take(10).toList();
              print('🧩 Claves actuales en news_cache (10): $keys');
            } catch (_) {}
          }
      }
      
      // 2. Si hay conexión, cargar de Supabase
      if (await _isConnected) {
        print('🌐 Cargando noticia desde Supabase: $news_item_id');
        final response = await _supabase
            .from('news_items')
            .select()
            .eq('news_item_id', int.parse(news_item_id))
            .single()
            .timeout(const Duration(seconds: 10));
        
        print('✅ Respuesta de Supabase recibida');
        final responseMap = Map<String, dynamic>.from(response);
        await _newsCache.put(news_item_id, responseMap);
        print('💾 Noticia guardada en cache: $news_item_id');
        
        final newsItem = _mapToNewsItem(responseMap);
        print('✅ Noticia mapeada correctamente desde Supabase');
        return newsItem;
      }
      
      // 3. Sin conexión y sin cache
      print('📴 Sin conexión y sin cache para noticia: $news_item_id');
      return null;
    } catch (e, stackTrace) {
      print('❌ Error cargando noticia: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  @override
  Future<List<Comment>> getComments(String news_item_id) async {
    try {
      final cacheKey = 'comments_$news_item_id';
      
      // ✅ PRIMERO VER SI ESTÁ EN CACHE
      final cachedComments = _commentsCache.get(cacheKey);
      if (cachedComments != null && cachedComments is List) {
        print('📱 Usando comentarios desde cache: $news_item_id');
        return cachedComments.map<Comment>((comment) {
          final commentMap = Map<String, dynamic>.from(comment);
          return Comment(
            comment_id: commentMap['comment_id']?.toString() ?? '',
            news_item_id: commentMap['news_item_id']?.toString() ?? '',
            user_profile_id: commentMap['user_profile_id']?.toString() ?? '',
            user_name: commentMap['user_name'] as String? ?? 'Usuario',
            content: commentMap['content'] as String? ?? '',
            timestamp: commentMap['timestamp'] != null 
                ? DateTime.parse(commentMap['timestamp'] as String)
                : DateTime.now(),
          );
        }).toList();
      }
      
      // ✅ SI HAY CONEXIÓN, CARGAR DESDE SUPABASE
      if (await _isConnected) {
        print('🌐 Cargando comentarios desde Supabase: $news_item_id');
        final response = await _supabase
            .from('comments')
            .select()
            .eq('news_item_id', int.parse(news_item_id))
            .order('timestamp', ascending: false)
            .timeout(const Duration(seconds: 10));

        // ✅ CONVERTIR A LISTA DE MAPS
        final commentsList = response.map((comment) => Map<String, dynamic>.from(comment)).toList();
        
        // ✅ GUARDAR EN CACHE
        await _commentsCache.put(cacheKey, commentsList);
        
        return response.map<Comment>((comment) {
          return Comment(
            comment_id: comment['comment_id']?.toString() ?? 'unknown',
            news_item_id: comment['news_item_id']?.toString() ?? news_item_id,
            user_profile_id: comment['user_profile_id']?.toString() ?? '1',
            user_name: comment['user_name'] as String? ?? 'Usuario',
            content: comment['content'] as String? ?? '',
            timestamp: comment['timestamp'] != null 
                ? DateTime.parse(comment['timestamp'] as String)
                : DateTime.now(),
          );
        }).toList();
      } else {
        // ✅ SI NO HAY CONEXIÓN, USAR CACHE O DATOS VACÍOS
        print('📴 Sin conexión, sin comentarios en cache');
        return [];
      }
    } catch (e) {
      print('❌ Error cargando comentarios: $e');
      return [];
    }
  }

  Future<int> getRatingsCount(String news_item_id) async {
    try {
      final cacheKey = 'ratings_count_$news_item_id';
      
      // ✅ PRIMERO VER SI ESTÁ EN CACHE
      final cachedCount = _ratingsCache.get(cacheKey);
      if (cachedCount != null && cachedCount is int) {
        return cachedCount;
      }
      
      // ✅ SI HAY CONEXIÓN, CARGAR DESDE SUPABASE
      if (await _isConnected) {
        final response = await _supabase
            .from('rating_items')
            .select()
            .eq('news_item_id', int.parse(news_item_id))
            .timeout(const Duration(seconds: 10));
        
        final count = response.length;
        
        // ✅ GUARDAR EN CACHE
        await _ratingsCache.put(cacheKey, count);
        
        return count;
      } else {
        // ✅ SI NO HAY CONEXIÓN, USAR CACHE O CERO
        return (cachedCount as int?) ?? 0;
      }
    } catch (e) {
      print('❌ Error contando ratings: $e');
      return 0;
    }
  }

  /// Liberar recursos (cancelar listener de conectividad)
  Future<void> dispose() async {
    try {
      await _connectivitySub?.cancel();
      _connectivitySub = null;
      print('🧹 HybridNewsRepository disposed (connectivity listener cancelled)');
    } catch (e) {
      print('⚠️ Error disposing HybridNewsRepository: $e');
    }
  }

  @override
  Future<void> submitRating(RatingItem rating_item) async {
    try {
      final pendingKey = 'pending_ratings';
      
      if (await _isConnected) {
        // ✅ ENVIAR A SUPABASE SI HAY CONEXIÓN (sin rating_item_id, lo genera Supabase)
        await _supabase.from('rating_items').insert({
          'news_item_id': int.tryParse(rating_item.news_item_id) ?? 1,
          'user_profile_id': int.tryParse(rating_item.user_profile_id) ?? 1,
          'assigned_reliability_score': rating_item.assigned_reliability_score,
          'comment_text': rating_item.comment_text,
          'rating_date': rating_item.rating_date.toIso8601String(),
          'is_completed': rating_item.is_completed,
        });
        print('✅ Rating enviado a Supabase');
      } else {
        // ✅ GUARDAR LOCALMENTE SI NO HAY CONEXIÓN
  final pendingRatings = (_ratingsCache.get(pendingKey, defaultValue: <Map<String, dynamic>>[]) as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
        
        pendingRatings.add({
          'rating_item_id': rating_item.rating_item_id,
          'news_item_id': rating_item.news_item_id,
          'user_profile_id': rating_item.user_profile_id,
          'assigned_reliability_score': rating_item.assigned_reliability_score,
          'comment_text': rating_item.comment_text,
          'rating_date': rating_item.rating_date.toIso8601String(),
          'is_completed': rating_item.is_completed,
        });
        
        await _ratingsCache.put(pendingKey, pendingRatings);
        print('💾 Rating guardado localmente (pendiente de envío)');
      }
    } catch (e) {
      print('❌ Error enviando rating: $e');
    }
  }

  @override
  Future<void> submitComment(Comment comment) async {
    try {
      final pendingKey = 'pending_comments';
      
      if (await _isConnected) {
        // ✅ ENVIAR A SUPABASE SI HAY CONEXIÓN (sin comment_id, lo genera Supabase)
        await _supabase.from('comments').insert({
          'news_item_id': int.tryParse(comment.news_item_id) ?? 1,
          'user_profile_id': int.tryParse(comment.user_profile_id) ?? 1,
          'user_name': comment.user_name,
          'content': comment.content,
          'timestamp': comment.timestamp.toIso8601String(),
        });
        print('✅ Comentario enviado a Supabase');
      } else {
        // ✅ GUARDAR LOCALMENTE SI NO HAY CONEXIÓN
        final pendingComments = _commentsCache.get(pendingKey, defaultValue: <Map<String, dynamic>>[]) as List<Map<String, dynamic>>;
        
        pendingComments.add({
          'comment_id': 'local_${DateTime.now().millisecondsSinceEpoch}',
          'news_item_id': comment.news_item_id,
          'user_profile_id': comment.user_profile_id,
          'user_name': comment.user_name,
          'content': comment.content,
          'timestamp': comment.timestamp.toIso8601String(),
        });
        
        await _commentsCache.put(pendingKey, pendingComments);
        print('💾 Comentario guardado localmente (pendiente de envío)');
      }
    } catch (e) {
      print('❌ Error guardando comentario: $e');
      rethrow;
    }
  }

  // ✅ SINCRONIZAR DATOS PENDIENTES CUANDO HAY CONEXIÓN
  Future<void> syncPendingData() async {
    if (await _isConnected) {
      await _syncPendingRatings();
      await _syncPendingComments();
      await syncBookmarksIfNeeded();
    }
  }

  Future<void> _syncPendingRatings() async {
    final pendingKey = 'pending_ratings';
  final pendingRatings = (_ratingsCache.get(pendingKey, defaultValue: <Map<String, dynamic>>[]) as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
    
    if (pendingRatings.isNotEmpty) {
      for (final rating in pendingRatings) {
        try {
          // No enviar rating_id (puede ser local_xxx), dejar que Supabase lo genere
          final ratingToSync = Map<String, dynamic>.from(rating);
          // Eliminar ID local si existe y asegurar tipos correctos
          ratingToSync.remove('rating_item_id');
          // Coerciones de tipos requeridas por la BD
          final newsIdStr = ratingToSync['news_item_id']?.toString();
          final userIdStr = ratingToSync['user_profile_id']?.toString();
          final newsId = int.tryParse(newsIdStr ?? '');
          final userId = int.tryParse(userIdStr ?? '');
          if (newsId == null || userId == null) {
            print('❌ Omitiendo rating por IDs inválidos (news:$newsIdStr, user:$userIdStr)');
            continue;
          }
          ratingToSync['news_item_id'] = newsId;
          ratingToSync['user_profile_id'] = userId;
          // Fecha
          final rd = ratingToSync['rating_date'];
          if (rd is DateTime) {
            ratingToSync['rating_date'] = rd.toIso8601String();
          } else if (rd is String) {
            // Asegurar formato válido
            try {
              ratingToSync['rating_date'] = DateTime.parse(rd).toIso8601String();
            } catch (_) {}
          }
          // Score a num/double
          final score = ratingToSync['assigned_reliability_score'];
          if (score is String) {
            ratingToSync['assigned_reliability_score'] = double.tryParse(score) ?? 0.0;
          }
          // is_completed a bool
          final isCompleted = ratingToSync['is_completed'];
          if (isCompleted is String) {
            ratingToSync['is_completed'] = (isCompleted.toLowerCase() == 'true');
          }
          print('⬆️ Sincronizando rating: $ratingToSync');
          await _supabase.from('rating_items').insert(ratingToSync);
        } catch (e) {
          print('❌ Error sincronizando rating: $e');
        }
      }
      await _ratingsCache.put(pendingKey, <Map<String, dynamic>>[]);
      print('✅ Ratings pendientes sincronizados');
    }
  }

  Future<void> _syncPendingComments() async {
    final pendingKey = 'pending_comments';
    final pendingComments = _commentsCache.get(pendingKey, defaultValue: <Map<String, dynamic>>[]) as List<Map<String, dynamic>>;
    
    if (pendingComments.isNotEmpty) {
      for (final comment in pendingComments) {
        try {
          // No enviar comment_id (puede ser local_xxx), dejar que Supabase lo genere
          final commentToSync = Map<String, dynamic>.from(comment);
          commentToSync.remove('comment_id'); // Eliminar ID local si existe
          // Coerciones de tipos requeridas por la BD
          final newsIdStr = commentToSync['news_item_id']?.toString();
          final userIdStr = commentToSync['user_profile_id']?.toString();
          final newsId = int.tryParse(newsIdStr ?? '');
          final userId = int.tryParse(userIdStr ?? '');
          if (newsId == null || userId == null) {
            print('❌ Omitiendo comentario por IDs inválidos (news:$newsIdStr, user:$userIdStr)');
            continue;
          }
          commentToSync['news_item_id'] = newsId;
          commentToSync['user_profile_id'] = userId;
          // timestamp
          final ts = commentToSync['timestamp'];
          if (ts is DateTime) {
            commentToSync['timestamp'] = ts.toIso8601String();
          } else if (ts is String) {
            try {
              commentToSync['timestamp'] = DateTime.parse(ts).toIso8601String();
            } catch (_) {}
          }
          // Log no sensible (evitar mostrar el texto completo del comentario)
          final logCopy = Map<String, dynamic>.from(commentToSync);
          if (logCopy.containsKey('content')) {
            logCopy['content'] = '<redacted>'; // no exponer contenido
          }
          print('⬆️ Sincronizando comentario: $logCopy');
          await _supabase.from('comments').insert(commentToSync);
        } catch (e) {
          print('❌ Error sincronizando comentario: $e');
        }
      }
      await _commentsCache.put(pendingKey, <Map<String, dynamic>>[]);
      print('✅ Comentarios pendientes sincronizados');
    }
  }
  NewsItem _mapToNewsItem(Map<String, dynamic> response) {
  return NewsItem(
    news_item_id: (response['news_item_id']?.toString() ?? '0'),
    user_profile_id: (response['user_profile_id']?.toString() ?? '0'),
    title: response['title'] as String? ?? 'Sin título',
    short_description: response['short_description'] as String? ?? '',
    image_url: response['image_url'] as String? ?? '',
    category_id: (response['category_id']?.toString() ?? ''), // ✅ CONVERTIR A STRING
    author_type: response['author_type'] as String? ?? '',
    author_institution: response['author_institution'] as String? ?? '',
    days_since: (response['days_since'] as int?) ?? 0,
    comments_count: (response['comments_count'] as int?) ?? 0,
    average_reliability_score: (response['average_reliability_score'] as num?)?.toDouble() ?? 0.5,
    is_fake: response['is_fake'] as bool? ?? false,
    is_verified_source: response['is_verified_source'] as bool? ?? false,
    is_verified_data: response['is_verified_data'] as bool? ?? false,
    is_recognized_author: response['is_recognized_author'] as bool? ?? false,
    is_manipulated: response['is_manipulated'] as bool? ?? false,
    long_description: response['long_description'] as String? ?? '',
    original_source_url: response['original_source_url'] as String? ?? '',
    publication_date: response['publication_date'] != null 
        ? DateTime.parse(response['publication_date'] as String)
        : DateTime.now(),
    added_to_app_date: response['added_to_app_date'] != null
        ? DateTime.parse(response['added_to_app_date'] as String)
        : DateTime.now(),
    total_ratings: (response['total_ratings'] as int?) ?? 0,
  );
}


  late final SqliteNewsRepository sqlite;
  late final SupabaseNewsRepository remote;
  late final AuthRepository auth;

  Future<void> toggleBookmark(int newsId, {required bool value}) async {
    await sqlite.toggleBookmark(newsId, value: value);

    // Obtiene el perfil actual del usuario
    final userProfileId = await auth.currentUserProfileId();

    // Si hay usuario y conexión, intenta sincronizar de inmediato
    if (userProfileId != null && await _isConnected) {
      try {
        if (value) {
          await remote.pushBookmarks([newsId], userProfileId);
          await sqlite.markBookmarksSynced([newsId]);
          debugPrint('✅ Bookmark sincronizado remoto [$newsId]');
        } else {
          await remote.deleteBookmark(newsId, userProfileId);
          debugPrint('🗑️ Bookmark eliminado remoto [$newsId]');
        }
      } catch (e) {
        // Si falla, lo dejamos marcado como pendiente de sincronización
        debugPrint('⚠️ Error al sincronizar bookmark [$newsId]: $e');
      }
    }
  }

  /// Verifica si una noticia está marcada como guardada
  Future<bool> isBookmarked(int newsId) async {
    return sqlite.isBookmarked(newsId);
  }

  /// Obtiene todos los IDs de noticias guardadas localmente
  Future<List<int>> getBookmarkedIds() async {
    return sqlite.getBookmarkedIds();
  }

  /// Sincroniza los bookmarks pendientes cuando vuelve la conexión
  Future<void> syncBookmarksIfNeeded() async {
    final userProfileId = await auth.currentUserProfileId();
    if (userProfileId == null) return;

    final connected = await _isConnected;
    if (!connected) {
      debugPrint('🌐 Sin conexión, posponiendo sincronización de bookmarks');
      return;
    }

    final pending = await sqlite.takePendingBookmarks(100);
    if (pending.isEmpty) {
      debugPrint('🟢 No hay bookmarks pendientes');
      return;
    }

    try {
      await remote.pushBookmarks(pending, userProfileId);
      await sqlite.markBookmarksSynced(pending);
      debugPrint('✅ Bookmarks sincronizados con Supabase (${pending.length})');
    } catch (e) {
      debugPrint('⚠️ Fallo al sincronizar bookmarks pendientes: $e');
    }
  }

}
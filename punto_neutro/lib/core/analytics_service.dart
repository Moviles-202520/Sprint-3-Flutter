import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  int? _sessionId;
  DateTime? _sessionStart;
  // Track which news items have been counted in articles_viewed for the current session
  final Set<String> _seenArticlesForSession = {};
  // Track which categories have been recorded in viewed_categories for the current session
  final Set<int> _seenCategoriesForSession = {};
  // Pending categories applied before a session exists; flushed when session is created
  final Set<int> _pendingViewedCategories = {};
  // If a category filter is applied before a session exists, defer marking it
  bool _pendingUsedCategoryFilter = false;
  // Caches de inicio para medir correctamente started_at/completed_at
  final Map<String, DateTime> _ratingStartCache = {}; // key: "newsId:userId"
  final Map<int, DateTime> _commentStartCache = {};   // key: newsId
  // Cache para almacenar event_id de engagement_events creados en 'started' para comments
  // NOTE: we will no longer insert 'started' immediately; we cache the start time
  // and only flush (insert) when the screen is exited without completion.
  final Map<int, DateTime> _pendingCommentStarts = {}; // key: newsId -> started_at
  final Map<int, int> _pendingCommentUserIds = {}; // key: newsId -> userId
  // (no persistent cache for comment event_ids; we flush and don't keep event_id)
  // Cache para almacenar event_id de engagement_events creados en 'started'
  // For ratings we also cache start times before flushing
  final Map<String, DateTime> _pendingRatingStarts = {}; // key: "newsId:userId" -> started_at
  final Map<String, int> _ratingEventCache = {}; // key: "newsId:userId" -> event_id

  String _ratingKey(int newsItemId, int userProfileId) => '$newsItemId:$userProfileId';

  Future<void> startSession(int userProfileId) async {
    // 🔒 Bloquear tracking de sesiones anónimas/no autenticadas
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        print('⚠️ [SESSION] Usuario no autenticado - no se creará sesión');
        return;
      }
    } catch (e) {
      print('⚠️ [SESSION] Error verificando autenticación: $e');
      return;
    }
    
    _sessionStart = DateTime.now();
    _sessionId = null;
    // reset seen articles and categories for new session
    _seenArticlesForSession.clear();
    _seenCategoriesForSession.clear();
    final deviceInfo = DeviceInfoPlugin();
    String deviceType = 'unknown';
    String os = 'unknown';
    try {
      // Android
      final android = await deviceInfo.androidInfo;
      deviceType = 'mobile';
      os = 'Android ${android.version.release}';
    } catch (_) {
      try {
        // iOS
        final ios = await deviceInfo.iosInfo;
        deviceType = 'mobile';
        os = 'iOS ${ios.systemVersion}';
      } catch (_) {
        try {
          // Web
          final web = await deviceInfo.webBrowserInfo;
          deviceType = 'web';
          // Extract browser name from user-agent instead of full string
          final ua = web.userAgent ?? 'Web';
          if (ua.contains('Chrome') && !ua.contains('Edg')) {
            os = 'Chrome';
          } else if (ua.contains('Edg')) {
            os = 'Edge';
          } else if (ua.contains('Firefox')) {
            os = 'Firefox';
          } else if (ua.contains('Safari') && !ua.contains('Chrome')) {
            os = 'Safari';
          } else {
            os = 'Web Browser';
          }
        } catch (_) {
          try {
            // Windows
            final windows = await deviceInfo.windowsInfo;
            deviceType = 'desktop';
            os = 'Windows ${windows.productName}';
          } catch (_) {
            try {
              // MacOS
              final mac = await deviceInfo.macOsInfo;
              deviceType = 'desktop';
              os = 'MacOS ${mac.osRelease}';
            } catch (_) {
              try {
                // Linux
                final linux = await deviceInfo.linuxInfo;
                deviceType = 'desktop';
                os = 'Linux ${linux.prettyName}';
              } catch (_) {
                deviceType = 'unknown';
                os = 'unknown';
              }
            }
          }
        }
      }
    }
    try {
      // Close stale sessions with null end_time for this user.
      // Some Supabase/Postgrest filters behave differently across versions, so
      // first fetch any sessions with null end_time for this user, then update them individually.
      try {
        final stale = await _supabase
            .from('user_sessions')
            .select('user_session_id,start_time')
            .filter('end_time', 'is', null)
            .eq('user_profile_id', userProfileId);
        if (stale.isNotEmpty) {
          for (final row in stale) {
            try {
              final id = row['user_session_id'];
              final startStr = row['start_time'];
              int duration = 0;
              try {
                if (startStr != null) {
                  final parsed = DateTime.parse(startStr);
                  duration = _sessionStart!.difference(parsed).inSeconds;
                  if (duration < 0) duration = 0;
                }
              } catch (_) {
                duration = 0;
              }
              await _supabase.from('user_sessions').update({
                'end_time': _sessionStart!.toIso8601String(),
                'duration_seconds': duration,
              }).eq('user_session_id', id);
            } catch (e) {
              // continue closing other stale rows
              print('⚠️ [SESSION] Error closing stale session row: $e');
            }
          }
        }
      } catch (e) {
        print('⚠️ [SESSION] Error querying stale sessions: $e');
      }

      final response = await _supabase.from('user_sessions').insert({
        'user_profile_id': userProfileId,
        'start_time': _sessionStart!.toIso8601String(),
        'device_type': deviceType,
        'operating_system': os,
        'used_category_filter': false,
        'articles_viewed': 0,
      }).select('user_session_id');
      print('✅ [SESSION] Insert response: $response');
      if (response.isNotEmpty && response.first['user_session_id'] != null) {
        _sessionId = response.first['user_session_id'] as int;
        print('✅ [SESSION] Session started with ID: $_sessionId');
        if (_pendingUsedCategoryFilter) {
          try {
            if (_sessionId != null) {
              await _supabase.from('user_sessions').update({'used_category_filter': true}).eq('user_session_id', _sessionId!);
            }
          } catch (_) {}
          _pendingUsedCategoryFilter = false;
        }
        // Flush any pending viewed categories that were applied before session creation
        if (_pendingViewedCategories.isNotEmpty) {
          try {
            // Query already existing viewed_categories for this session to avoid duplicates
            final existing = await _supabase.from('viewed_categories').select('category_id').eq('user_session_id', _sessionId!);
            final existingSet = <int>{};
            if (existing.isNotEmpty) {
              for (final r in existing) {
                try {
                  final cid = r['category_id'];
                  if (cid is int) existingSet.add(cid);
                } catch (_) {}
              }
            }
            final toInsert = _pendingViewedCategories.where((c) => !existingSet.contains(c)).toList();
            if (toInsert.isNotEmpty) {
              try {
                final current = _supabase.auth.currentUser;
                final sess = _supabase.auth.currentSession;
                print('🔐 [FILTER] Flushing pending categories as user ${current?.id}, session present: ${sess != null}');
              } catch (_) {}
              final inserts = toInsert.map((catId) => {
                'category_id': catId,
                'user_session_id': _sessionId!,
              }).toList();
              await _supabase.from('viewed_categories').insert(inserts);
              _seenCategoriesForSession.addAll(toInsert);
            }
          } catch (e) {
            print('❌ [FILTER] Error flushing pending viewed categories: $e');
          } finally {
            _pendingViewedCategories.clear();
          }
        }
      } else {
        print('❌ [SESSION] No session_id returned. Response: $response');
      }
    } catch (e, st) {
      print('❌ [SESSION] Error inserting session: $e');
      print('❌ [SESSION] StackTrace: $st');
      print('❌ [SESSION] user_profile_id sent: $userProfileId');
    }
  }

  Future<void> endSession() async {
    print('🔔 [SESSION] endSession() llamado. sessionId: $_sessionId, sessionStart: $_sessionStart');
    if (_sessionId == null || _sessionStart == null) {
      print('⚠️ [SESSION] No hay sesión activa para cerrar.');
      return;
    }
    
    // IMPORTANTE: Flush de eventos pendientes ANTES de cerrar la sesión
    // para que se guarden aunque el ViewModel no haga dispose (ej: cierre de app en web)
    print('🔄 [SESSION] Flushing pending events before closing session...');
    print('📊 [SESSION] Pending ratings: ${_pendingRatingStarts.length}, Pending comments: ${_pendingCommentStarts.length}');
    
    // Flush pending rating starts
    final pendingRatings = Map<String, DateTime>.from(_pendingRatingStarts);
    for (final entry in pendingRatings.entries) {
      final parts = entry.key.split(':');
      if (parts.length == 2) {
        final newsId = int.tryParse(parts[0]);
        final userId = int.tryParse(parts[1]);
        if (newsId != null && userId != null) {
          try {
            final createdAt = entry.value.toUtc().toIso8601String();
            print('💾 [SESSION] Inserting rating started: newsId=$newsId, userId=$userId, session=$_sessionId');
            await _supabase.from('engagement_events').insert({
              'user_profile_id': userId,
              'user_session_id': _sessionId,
              'news_item_id': newsId,
              'event_type': 'rating',
              'action': 'started',
              'created_at': createdAt,
            });
            print('✅ [SESSION] Flushed pending rating started for news $newsId');
          } catch (e) {
            print('❌ [SESSION] Error flushing rating: $e');
          }
        }
      }
    }
    _pendingRatingStarts.clear();
    
    // Flush pending comment starts
    final pendingComments = Map<int, DateTime>.from(_pendingCommentStarts);
    for (final entry in pendingComments.entries) {
      try {
        final createdAt = entry.value.toUtc().toIso8601String();
        final userId = _pendingCommentUserIds[entry.key];
        print('💾 [SESSION] Inserting comment started: newsId=${entry.key}, userId=$userId, session=$_sessionId');
        await _supabase.from('engagement_events').insert({
          'user_profile_id': userId,
          'user_session_id': _sessionId,
          'news_item_id': entry.key,
          'event_type': 'comment',
          'action': 'started',
          'created_at': createdAt,
        });
        print('✅ [SESSION] Flushed pending comment started for news ${entry.key}');
      } catch (e) {
        print('❌ [SESSION] Error flushing comment: $e');
      }
    }
    _pendingCommentStarts.clear();
    _pendingCommentUserIds.clear();
    
    final endTime = DateTime.now();
    final duration = endTime.difference(_sessionStart!).inSeconds;
    print('📊 [SESSION] Actualizando: end_time=${endTime.toIso8601String()}, duration_seconds=$duration');
    await _supabase.from('user_sessions').update({
      'end_time': endTime.toIso8601String(),
      'duration_seconds': duration,
    }).eq('user_session_id', _sessionId!);
    print('✅ [SESSION] end_time y duration_seconds actualizados correctamente');
    _sessionId = null;
    _sessionStart = null;
    // clear per-session caches
    _seenArticlesForSession.clear();
    _seenCategoriesForSession.clear();
    _pendingViewedCategories.clear();
  }

  /// Synchronous version of endSession for use in pagehide/beforeunload events.
  /// Fires endSession() without awaiting (best effort).
  void endSessionSync() {
    print('🔴 [SESSION] endSessionSync() llamado (sync)');
    // Call endSession without awaiting - let it run in background
    // This is the best we can do in a synchronous context like pagehide
    endSession().then((_) {
      print('✅ [SESSION] endSessionSync completed');
    }).catchError((e) {
      print('❌ [SESSION] endSessionSync error: $e');
    });
  }

  Future<void> trackCommentStarted(int newsItemId, [int? userProfileId]) async {
    // Cache the start timestamp and don't send to server yet. The UI/ViewModel
    // will call flushCommentStart when the screen is popped so we either send
    // a 'started' (if not completed) or nothing (if completed and handled).
    print('📝 [EVENT] cache trackCommentStarted - newsItemId: $newsItemId, userId: $userProfileId');
    final now = DateTime.now();
    _commentStartCache[newsItemId] = now;
    _pendingCommentStarts[newsItemId] = now;
    if (userProfileId != null) {
      _pendingCommentUserIds[newsItemId] = userProfileId;
    }
  }

  /// Flush a pending comment 'started' for [newsItemId] by inserting an
  /// engagement_event with action='started' and created_at = cached started time.
  /// This is intended to be called when the user leaves the news detail screen
  /// without completing the comment.
  Future<void> flushCommentStart(int newsItemId, [int? userProfileId]) async {
    final startedDt = _pendingCommentStarts.remove(newsItemId);
    if (startedDt == null) return; // nothing pending
    try {
      final createdAt = startedDt.toUtc().toIso8601String();
      await _supabase.from('engagement_events').insert({
        'user_profile_id': userProfileId,
        'user_session_id': _sessionId,
        'news_item_id': newsItemId,
        'event_type': 'comment',
        'action': 'started',
        'created_at': createdAt,
      });
      print('✅ [EVENT] Flushed comment started for news $newsItemId at $createdAt');
    } catch (e, st) {
      print('❌ [EVENT] Error flushing comment started: $e');
      print(st);
    }
  }

  Future<void> trackCommentCompleted(int newsItemId, int userProfileId, String content) async {
    try {
      print('📝 [EVENT] trackCommentCompleted - newsItemId: $newsItemId, userId: $userProfileId, sessionId: $_sessionId');
      final nowDt = DateTime.now();
      final startedDt = _commentStartCache.remove(newsItemId) ?? nowDt;
      final now = nowDt.toUtc().toIso8601String();
      final started = startedDt.toUtc().toIso8601String();
      await _supabase.from('comments').insert({
        'news_item_id': newsItemId,
        'user_profile_id': userProfileId,
        'user_name': 'You',
        'content': content,
        'timestamp': now,
        'started_at': started,
        'completed_at': now,
        'is_completed': true,
      });
      // Intentar actualizar el engagement_event 'started' si existe, sino insertar uno nuevo
      // Remove any pending cached start since we're completing now.
      _pendingCommentStarts.remove(newsItemId);

      // Insert a completed event. If there was previously a started row already
      // flushed, it will remain (but business logic prefers completed rows
      // to be represented in comments table and engagement events can be used
      // for aggregation). We avoid trying to update earlier started rows here
      // because we now flush started only on exit.
      {
        // Intentamos localizar y actualizar el 'started' más relevante.
        await _supabase.from('engagement_events').insert({
          'user_profile_id': userProfileId,
          'user_session_id': _sessionId,
          'news_item_id': newsItemId,
          'event_type': 'comment',
          'action': 'completed',
        });
      }
      print('✅ [EVENT] Comment completed registrado exitosamente');
    } catch (e, st) {
      print('❌ [EVENT] Error en trackCommentCompleted: $e');
      print(st);
    }
  }

  Future<void> trackFilterApplied(int categoryId) async {
    print('🔔 [FILTER] trackFilterApplied() llamado. categoryId: $categoryId, sessionId: $_sessionId');
    if (_sessionId == null) {
      // Defer marking the session as using a category filter until a session exists.
      _pendingUsedCategoryFilter = true;
      // Also remember which category was selected so we can flush it later
      _pendingViewedCategories.add(categoryId);
      print('⚠️ [FILTER] No hay sesión activa — guardando categoryId $categoryId en pendingViewedCategories');
      return;
    }

    // If we've already recorded this category for the current session, skip.
    if (_seenCategoriesForSession.contains(categoryId)) {
      print('ℹ️ [FILTER] categoryId $categoryId ya registrada para session $_sessionId — omitiendo');
      return;
    }

    try {
      await _supabase.from('viewed_categories').insert({
        'category_id': categoryId,
        'user_session_id': _sessionId!,
      });
      _seenCategoriesForSession.add(categoryId);
      // Also set the session flag that a filter was used
      await _supabase.from('user_sessions').update({
        'used_category_filter': true,
      }).eq('user_session_id', _sessionId!);
      print('✅ [FILTER] categoryId $categoryId registrada y used_category_filter actualizado a TRUE para sessionId: $_sessionId');
    } catch (e, st) {
      print('❌ [FILTER] Error registrando filtro: $e');
      print(st);
    }
  }

  Future<void> trackRatingGiven(int newsItemId, int userProfileId, double score, String comment) async {
    try {
      print('⭐ [EVENT] trackRatingGiven - newsItemId: $newsItemId, userId: $userProfileId, score: $score, sessionId: $_sessionId');
  final nowDt = DateTime.now();
  // Remove pending start to avoid double-insert when we flushed on exit
  _pendingRatingStarts.remove(_ratingKey(newsItemId, userProfileId));
  final startedDt = _ratingStartCache.remove(_ratingKey(newsItemId, userProfileId)) ?? nowDt;
      final now = nowDt.toUtc().toIso8601String();
      final started = startedDt.toUtc().toIso8601String();
      await _supabase.from('rating_items').insert({
        'news_item_id': newsItemId,
        'user_profile_id': userProfileId,
        'assigned_reliability_score': score,
        'comment_text': comment,
        'rating_date': now,
        'started_at': started,
        'completed_at': now,
        'is_completed': true,
      });
      // Intentar actualizar el engagement_event 'started' si existe, sino insertar uno nuevo
      final key = _ratingKey(newsItemId, userProfileId);
      final existingEventId = _ratingEventCache.remove(key);
      if (existingEventId != null) {
        await _supabase.from('engagement_events').update({
          'user_profile_id': userProfileId,
          'user_session_id': _sessionId,
          'news_item_id': newsItemId,
          'event_type': 'rating',
          'action': 'completed',
        }).eq('event_id', existingEventId);
      } else {
        await _supabase.from('engagement_events').insert({
          'user_profile_id': userProfileId,
          'user_session_id': _sessionId,
          'news_item_id': newsItemId,
          'event_type': 'rating',
          'action': 'completed',
        });
      }
      print('✅ [EVENT] Rating given registrado exitosamente');
    } catch (e, st) {
      print('❌ [EVENT] Error en trackRatingGiven: $e');
      print(st);
    }
  }

  Future<void> trackRatingStarted(int newsItemId, int userProfileId) async {
    // Cache the start timestamp and don't send to server yet. The UI/ViewModel
    // should call flushRatingStart when the screen is popped so we either send
    // a 'started' (if not completed) or nothing (if completed and handled).
    print('⭐ [EVENT] cache trackRatingStarted - newsItemId: $newsItemId, userId: $userProfileId');
    final now = DateTime.now();
    _ratingStartCache[_ratingKey(newsItemId, userProfileId)] = now;
    _pendingRatingStarts[_ratingKey(newsItemId, userProfileId)] = now;
  }

  /// Cache a rating start and flush later if the screen is exited without completion
  Future<void> flushRatingStart(int newsItemId, int userProfileId) async {
    final key = _ratingKey(newsItemId, userProfileId);
    final startedDt = _pendingRatingStarts.remove(key);
    if (startedDt == null) return;
    try {
      final createdAt = startedDt.toUtc().toIso8601String();
      final response = await _supabase.from('engagement_events').insert({
        'user_profile_id': userProfileId,
        'user_session_id': _sessionId,
        'news_item_id': newsItemId,
        'event_type': 'rating',
        'action': 'started',
        'created_at': createdAt,
      }).select('event_id');
      if (response.isNotEmpty && response.first['event_id'] != null) {
        final insertedId = response.first['event_id'] as int;
        _ratingEventCache[key] = insertedId;
      }
      print('✅ [EVENT] Flushed rating started for news $newsItemId');
    } catch (e, st) {
      print('❌ [EVENT] Error flushing rating started: $e');
      print(st);
    }
  }

  /// Increment the articles_viewed counter for the current session.
  /// This will only count a given [newsItemId] once per session.
  /// Increment the articles_viewed counter for the current session.
  /// This will only count a given [newsItemId] once per session.
  /// If [categoryId] is provided, it will also record the category in
  /// `viewed_categories` (one row per category per session).
  Future<void> incrementArticlesViewed(String newsItemId, [int? categoryId]) async {
    // If there's no session yet, defer category recording (but we can't update articles_viewed)
    if (_sessionId == null) {
      if (categoryId != null) {
        _pendingViewedCategories.add(categoryId);
        print('⚠️ [SESSION] No active session - deferring category $categoryId');
      }
      return;
    }

    // Count unique articles per session (only once per newsItemId)
    final isNewArticle = !_seenArticlesForSession.contains(newsItemId);
    if (isNewArticle) {
      _seenArticlesForSession.add(newsItemId);
      try {
        final session = await _supabase.from('user_sessions').select('articles_viewed').eq('user_session_id', _sessionId!).single();
        final current = session['articles_viewed'] ?? 0;
        await _supabase.from('user_sessions').update({
          'articles_viewed': current + 1,
        }).eq('user_session_id', _sessionId!);
      } catch (e, st) {
        print('❌ [SESSION] Error incrementando articles_viewed: $e');
        print(st);
      }
    }

    // Record the category as viewed for this session (if provided)
    if (categoryId != null) {
      // If we've already recorded this category for the current session, skip.
      if (_seenCategoriesForSession.contains(categoryId)) {
        print('ℹ️ [FILTER] categoryId $categoryId ya registrada para session $_sessionId — omitiendo');
        return;
      }

      try {
        // Defensive check: query existing to avoid RLS/duplicate errors
        print('🔎 [FILTER] Checking existing viewed_categories for session=$_sessionId');
        final existing = await _supabase.from('viewed_categories').select('category_id').eq('user_session_id', _sessionId!);
        final existingSet = <int>{};
        if (existing.isNotEmpty) {
          for (final r in existing) {
            try {
              final cid = r['category_id'];
              if (cid is int) existingSet.add(cid);
            } catch (_) {}
          }
        }
        print('🔎 [FILTER] existing categories for session=$_sessionId -> $existingSet');
        if (!existingSet.contains(categoryId)) {
          print('✳️ [FILTER] inserting viewed_categories {category_id: $categoryId, user_session_id: $_sessionId}');
          // Debug: print auth info to help diagnose RLS errors
          try {
            final current = _supabase.auth.currentUser;
            final sess = _supabase.auth.currentSession;
            print('🔐 [FILTER] Supabase auth currentUser: ${current?.id}, session present: ${sess != null}');
          } catch (_) {}
          // Do a simple insert without requesting returned rows to avoid possible SELECT/RETURNING permission issues
          await _supabase.from('viewed_categories').insert({
            'category_id': categoryId,
            'user_session_id': _sessionId!,
          });
          print('✳️ [FILTER] insert attempted');
        } else {
          print('ℹ️ [FILTER] category $categoryId already present in DB for session=$_sessionId');
        }
        _seenCategoriesForSession.add(categoryId);
      } catch (e, st) {
        print('❌ [FILTER] Error registrando viewed_categories desde incrementArticlesViewed: $e');
        print(st);
        // Fallback: store pending so it can be flushed later when session exists
        _pendingViewedCategories.add(categoryId);
      }
    }
  }
}

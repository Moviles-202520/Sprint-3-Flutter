import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ✅ NUEVO ANALYTICS DASHBOARD CON LAS 5 BUSINESS QUESTIONS REQUERIDAS
/// Implementa las BQ específicas solicitadas para el dashboard
class AnalyticsDashboardViewModel extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Streams para datos en tiempo real
  StreamSubscription<List<Map<String, dynamic>>>? _ratingsStream;
  StreamSubscription<List<Map<String, dynamic>>>? _sessionsStream;
  StreamSubscription<List<Map<String, dynamic>>>? _engagementStream;

  // ✅ BQ1: Personal bias score vs community averages
  Map<String, dynamic> _personalBiasData = {};
  
  // ✅ BQ2: Veracity ratings by source
  List<Map<String, dynamic>> _sourceVeracityData = [];
  
  // ✅ BQ3: Conversion rate from shared articles
  Map<String, dynamic> _conversionRateData = {};
  
  // ✅ BQ4: Rating distribution by category
  List<Map<String, dynamic>> _categoryDistributionData = [];
  
  // ✅ BQ5: Engagement vs accuracy correlation
  Map<String, dynamic> _engagementAccuracyData = {};

  bool _isLoading = false;
  String? _error;

  // Getters para la UI
  Map<String, dynamic> get personalBiasData => _personalBiasData;
  List<Map<String, dynamic>> get sourceVeracityData => _sourceVeracityData;
  Map<String, dynamic> get conversionRateData => _conversionRateData;
  List<Map<String, dynamic>> get categoryDistributionData => _categoryDistributionData;
  Map<String, dynamic> get engagementAccuracyData => _engagementAccuracyData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// ✅ INICIALIZAR DASHBOARD CON TODAS LAS BQ
  Future<void> initializeDashboard({int? userId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadBQ1PersonalBiasScore(userId),
        _loadBQ2SourceVeracityAnalysis(),
        _loadBQ3ConversionRateAnalysis(),
        _loadBQ4CategoryDistribution(),
        _loadBQ5EngagementAccuracyCorrelation(),
      ]);

      // Iniciar streams en tiempo real
      _startRealTimeUpdates();
      
    } catch (e) {
      _error = 'Error cargando dashboard: $e';
      print('❌ Error en dashboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ✅ BQ1: Personal bias score vs community averages
  Future<void> _loadBQ1PersonalBiasScore(int? userId) async {
    try {
      // Obtener user_profile_id desde user_profiles usando auth id
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId == null) {
        _personalBiasData = {'error': 'Usuario no autenticado'};
        return;
      }

      // Buscar user_profile_id
      final userProfile = await _supabase
          .from('user_profiles')
          .select('user_profile_id')
          .eq('user_auth_id', authUserId)
          .maybeSingle();

      if (userProfile == null) {
        _personalBiasData = {'error': 'Perfil de usuario no encontrado'};
        return;
      }

      final userProfileId = userProfile['user_profile_id'] as int;

      // Obtener ratings del usuario
      final userRatings = await _supabase
          .from('rating_items')
          .select('assigned_reliability_score, news_item_id')
          .eq('user_profile_id', userProfileId);

      // Obtener promedios de la comunidad
      final communityAvgs = await _supabase
          .from('rating_items')
          .select('assigned_reliability_score')
          .neq('user_profile_id', userProfileId);

      if (userRatings.isEmpty) {
        _personalBiasData = {
          'user_ratings_count': 0,
          'message': 'Necesitas más ratings para ver tu análisis'
        };
        return;
      }

      // Calcular promedios del usuario (solo reliability, bias no existe en Supabase)
      final userAvgReliability = userRatings
          .where((r) => r['assigned_reliability_score'] != null)
          .map((r) => (r['assigned_reliability_score'] as num).toDouble())
          .fold(0.0, (a, b) => a + b) / userRatings.where((r) => r['assigned_reliability_score'] != null).length;

      // Calcular promedios de la comunidad
      final validCommunityRatings = communityAvgs.where((r) => r['assigned_reliability_score'] != null).toList();
      final communityAvgReliability = validCommunityRatings.isNotEmpty
          ? validCommunityRatings
              .map((r) => (r['assigned_reliability_score'] as num).toDouble())
              .reduce((a, b) => a + b) / validCommunityRatings.length
          : 0.0;

      _personalBiasData = {
        'user_profile_id': userProfileId,
        'user_ratings_count': userRatings.length,
        'user_avg_reliability': userAvgReliability,
        'user_avg_bias': userAvgReliability, // Usar reliability como proxy (bias no existe)
        'community_avg_reliability': communityAvgReliability,
        'community_avg_bias': communityAvgReliability, // Usar reliability como proxy
        'reliability_difference': userAvgReliability - communityAvgReliability,
        'bias_difference': 0.0, // No disponible en Supabase
        'last_updated': DateTime.now().toIso8601String(),
      };

      print('✅ BQ1 Personal Bias Score cargado (${userRatings.length} ratings)');
    } catch (e) {
      print('❌ Error en BQ1: $e');
      _personalBiasData = {'error': e.toString()};
    }
  }

  /// ✅ BQ2: Source veracity analysis
  Future<void> _loadBQ2SourceVeracityAnalysis() async {
    try {
      // Query manual para obtener ratings por fuente (usando author_institution)
      final ratingsWithSource = await _supabase
          .from('rating_items')
          .select('''
            assigned_reliability_score,
            news_items!inner(
              news_item_id,
              author_institution
            )
          ''');

      // Agrupar por fuente y calcular promedios
      final Map<String, List<double>> sourceRatings = {};
      
      for (final rating in ratingsWithSource) {
        final sourceName = rating['news_items']['author_institution'] as String? ?? 'Unknown';
        final reliabilityRaw = rating['assigned_reliability_score'];
        if (reliabilityRaw == null) continue; // Skip nulls
        final reliability = (reliabilityRaw as num).toDouble();
        
        sourceRatings.putIfAbsent(sourceName, () => []);
        sourceRatings[sourceName]!.add(reliability);
      }

      _sourceVeracityData = sourceRatings.entries.map((entry) {
        final ratings = entry.value;
        final avg = ratings.reduce((a, b) => a + b) / ratings.length;
        
        return {
          'source_name': entry.key,
          'avg_reliability': avg,
          'total_ratings': ratings.length,
        };
      }).toList();

      // Ordenar por promedio descendente
      _sourceVeracityData.sort((a, b) => 
        (b['avg_reliability'] as double).compareTo(a['avg_reliability'] as double)
      );

      print('✅ BQ2 Source Veracity Analysis cargado (${_sourceVeracityData.length} fuentes)');
    } catch (e) {
      print('❌ Error en BQ2: $e');
      _sourceVeracityData = [];
    }
  }

  /// ✅ BQ3: Conversion rate analysis
  Future<void> _loadBQ3ConversionRateAnalysis() async {
    try {
      // Obtener usuarios que llegaron por artículos compartidos
      final sharedArticleUsers = await _supabase
          .from('engagement_events')
          .select('user_profile_id, news_item_id')
          .eq('event_type', 'article_shared')
          .eq('action', 'clicked');

      // Obtener usuarios activos (que han hecho ratings)
      final activeUsers = await _supabase
          .from('rating_items')
          .select('user_profile_id')
          .gt('assigned_reliability_score', 0);

      final totalSharedClicks = sharedArticleUsers.length;
      final uniqueSharedUsers = sharedArticleUsers
          .map((e) => e['user_profile_id'])
          .toSet()
          .length;

      final convertedUsers = sharedArticleUsers
          .where((shared) => activeUsers
              .any((active) => active['user_profile_id'] == shared['user_profile_id']))
          .map((e) => e['user_profile_id'])
          .toSet()
          .length;

      final conversionRate = uniqueSharedUsers > 0 
          ? (convertedUsers / uniqueSharedUsers) 
          : 0.0;

      _conversionRateData = {
        'total_shared': totalSharedClicks,
        'unique_users': uniqueSharedUsers,
        'rated_count': convertedUsers,
        'conversion_rate': conversionRate,
        'last_updated': DateTime.now().toIso8601String(),
      };

      print('✅ BQ3 Conversion Rate Analysis cargado');
    } catch (e) {
      print('❌ Error en BQ3: $e');
      _conversionRateData = {
        'total_shared': 0,
        'rated_count': 0,
        'conversion_rate': 0.0,
      };
    }
  }

  /// ✅ BQ4: Rating distribution by category
  Future<void> _loadBQ4CategoryDistribution() async {
    try {
      // Query manual para obtener distribución por categoría
      final ratingsWithCategory = await _supabase
          .from('rating_items')
          .select('''
            assigned_reliability_score,
            news_items!inner(
              category_id,
              categories!inner(name)
            )
          ''');

      // Agrupar por categoría
      final Map<int, Map<String, dynamic>> categoryGroups = {};
      
      for (final rating in ratingsWithCategory) {
        final categoryId = rating['news_items']['category_id'] as int?;
        if (categoryId == null) continue; // Skip nulls
        
        final categoryName = rating['news_items']['categories']['name'] as String? ?? 'Unknown';
        final reliabilityRaw = rating['assigned_reliability_score'];
        if (reliabilityRaw == null) continue; // Skip nulls
        final reliability = (reliabilityRaw as num).toDouble();
        
        if (!categoryGroups.containsKey(categoryId)) {
          categoryGroups[categoryId] = {
            'category_id': categoryId,
            'category_name': categoryName,
            'ratings': <double>[],
          };
        }
        
        (categoryGroups[categoryId]!['ratings'] as List<double>).add(reliability);
      }

      _categoryDistributionData = categoryGroups.values.map((group) {
        final ratings = group['ratings'] as List<double>;
        final avg = ratings.reduce((a, b) => a + b) / ratings.length;
        
        return {
          'category_id': group['category_id'],
          'category_name': group['category_name'],
          'rating_count': ratings.length,
          'avg_reliability': avg,
        };
      }).toList();

      // Ordenar por cantidad de ratings descendente
      _categoryDistributionData.sort((a, b) => 
        (b['rating_count'] as int).compareTo(a['rating_count'] as int)
      );

      print('✅ BQ4 Category Distribution cargado (${_categoryDistributionData.length} categorías)');
    } catch (e) {
      print('❌ Error en BQ4: $e');
      _categoryDistributionData = [];
    }
  }

  /// ✅ BQ5: Engagement vs accuracy correlation
  Future<void> _loadBQ5EngagementAccuracyCorrelation() async {
    try {
      // Obtener datos de sesiones con duración
      final sessionData = await _supabase
          .from('user_sessions')
          .select('user_session_id, duration_seconds, user_profile_id, articles_viewed')
          .gt('duration_seconds', 0);

      // Obtener ratings por sesión (agrupando por user_profile_id)
      final ratingData = await _supabase
          .from('rating_items')
          .select('user_profile_id, assigned_reliability_score');

      if (sessionData.isEmpty || ratingData.isEmpty) {
        _engagementAccuracyData = {
          'correlation': 0.0,
          'sample_size': 0,
          'message': 'Datos insuficientes para calcular correlación'
        };
        print('⚠️ BQ5: Datos insuficientes');
        return;
      }

      // Agrupar ratings por usuario para calcular accuracy
      final Map<int, List<double>> userRatings = {};
      for (final rating in ratingData) {
        final userId = rating['user_profile_id'] as int?;
        if (userId == null) continue; // Skip nulls
        
        final reliabilityRaw = rating['assigned_reliability_score'];
        if (reliabilityRaw == null) continue; // Skip nulls
        final reliability = (reliabilityRaw as num).toDouble();
        
        userRatings.putIfAbsent(userId, () => []);
        userRatings[userId]!.add(reliability);
      }

      // Calcular engagement y accuracy por usuario
      final List<Map<String, double>> userMetrics = [];
      
      // Agrupar sesiones por usuario
      final Map<int, List<Map<String, dynamic>>> userSessions = {};
      for (final session in sessionData) {
        final userId = session['user_profile_id'] as int?;
        if (userId == null) continue; // Skip nulls
        userSessions.putIfAbsent(userId, () => []);
        userSessions[userId]!.add(session);
      }

      for (final entry in userSessions.entries) {
        final userId = entry.key;
        final sessions = entry.value;
        
        if (userRatings.containsKey(userId) && userRatings[userId]!.isNotEmpty) {
          // Calcular engagement: suma de duration_seconds + articles_viewed
          final totalDuration = sessions
              .map((s) {
                final dur = s['duration_seconds'];
                if (dur == null) return 0.0;
                return (dur as num).toDouble();
              })
              .reduce((a, b) => a + b);
          final totalArticles = sessions
              .map((s) => (s['articles_viewed'] as num?)?.toDouble() ?? 0)
              .reduce((a, b) => a + b);
          
          final engagementScore = totalDuration / 60.0 + (totalArticles * 5); // minutos + bonus por artículo
          
          // Calcular accuracy: promedio de reliability scores
          final avgAccuracy = userRatings[userId]!.reduce((a, b) => a + b) / userRatings[userId]!.length;
          
          userMetrics.add({
            'engagement': engagementScore,
            'accuracy': avgAccuracy,
          });
        }
      }

      // Calcular correlación de Pearson
      final correlation = _calculatePearsonCorrelation(userMetrics);

      _engagementAccuracyData = {
        'correlation': correlation,
        'sample_size': userMetrics.length,
        'avg_engagement': userMetrics.isEmpty ? 0.0 : 
          userMetrics.map((m) => m['engagement']!).reduce((a, b) => a + b) / userMetrics.length,
        'avg_accuracy': userMetrics.isEmpty ? 0.0 :
          userMetrics.map((m) => m['accuracy']!).reduce((a, b) => a + b) / userMetrics.length,
        'last_updated': DateTime.now().toIso8601String(),
      };

      print('✅ BQ5 Engagement-Accuracy Correlation cargado (r=${correlation.toStringAsFixed(3)}, n=${userMetrics.length})');
    } catch (e) {
      print('❌ Error en BQ5: $e');
      _engagementAccuracyData = {
        'correlation': 0.0,
        'sample_size': 0,
      };
    }
  }

  /// Calcular correlación de Pearson entre engagement y accuracy
  double _calculatePearsonCorrelation(List<Map<String, double>> data) {
    if (data.length < 2) return 0.0;

    final engagements = data.map((d) => d['engagement']!).toList();
    final accuracies = data.map((d) => d['accuracy']!).toList();

    final n = data.length;
    final meanEngagement = engagements.reduce((a, b) => a + b) / n;
    final meanAccuracy = accuracies.reduce((a, b) => a + b) / n;

    double numerator = 0.0;
    double sumSqEngagement = 0.0;
    double sumSqAccuracy = 0.0;

    for (int i = 0; i < n; i++) {
      final diffEngagement = engagements[i] - meanEngagement;
      final diffAccuracy = accuracies[i] - meanAccuracy;
      
      numerator += diffEngagement * diffAccuracy;
      sumSqEngagement += diffEngagement * diffEngagement;
      sumSqAccuracy += diffAccuracy * diffAccuracy;
    }

    final denominator = sqrt(sumSqEngagement * sumSqAccuracy);
    return denominator == 0 ? 0.0 : numerator / denominator;
  }

  /// ✅ STREAMS EN TIEMPO REAL
  void _startRealTimeUpdates() {
    // Rating updates para BQ1 y BQ4
    _ratingsStream?.cancel();
    _ratingsStream = _supabase
        .from('rating_items')
        .stream(primaryKey: ['rating_item_id'])
        .listen((data) {
      print('📊 Ratings actualizados en tiempo real');
      // Re-calcular BQ1 y BQ4 cuando hay nuevos ratings
      _loadBQ1PersonalBiasScore(null);
      _loadBQ4CategoryDistribution();
    });

    // Session updates para BQ3 y BQ5
    _sessionsStream?.cancel();
    _sessionsStream = _supabase
        .from('user_sessions')
        .stream(primaryKey: ['session_id'])
        .listen((data) {
      print('📊 Sesiones actualizadas en tiempo real');
      _loadBQ5EngagementAccuracyCorrelation();
    });

    // Engagement updates para BQ3
    _engagementStream?.cancel();
    _engagementStream = _supabase
        .from('engagement_events')
        .stream(primaryKey: ['event_id'])
        .listen((data) {
      print('📊 Engagement actualizado en tiempo real');
      _loadBQ3ConversionRateAnalysis();
    });
  }

  @override
  void dispose() {
    _ratingsStream?.cancel();
    _sessionsStream?.cancel();
    _engagementStream?.cancel();
    super.dispose();
  }
}

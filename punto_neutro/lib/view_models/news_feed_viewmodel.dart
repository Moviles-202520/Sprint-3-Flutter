import 'package:flutter/foundation.dart';
import '../core/image_cache_service.dart';
import '../domain/repositories/news_repository.dart';
import '../domain/models/news_item.dart';

class NewsFeedViewModel extends ChangeNotifier {
  final NewsRepository _repository;
  
  List<NewsItem> _allNewsItems = [];
  List<NewsItem> _filteredNewsItems = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  String? _selectedCategoryId;

  NewsFeedViewModel(this._repository) {
    _loadNews();
  }

  List<NewsItem> get newsItems => _filteredNewsItems;
  bool get isLoading => _isLoading;
  int get currentIndex => _currentIndex;
  String? get selectedCategoryId => _selectedCategoryId;

  Future<void> _loadNews() async {
    try {
      _isLoading = true;
      notifyListeners();
      print('🔄 Cargando noticias (lista completa)...');
      final loadedNews = await _repository.getNewsList();
      _allNewsItems = loadedNews;
      _applyCategoryFilter();
      print('📊 Total cargado: ${_allNewsItems.length} noticias');
    } catch (e) {
      print('❌ Error cargando feed: $e');
      _allNewsItems = [];
      _filteredNewsItems = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void refreshNews() {
    _loadNews();
  }

  void setCategoryFilter(String? categoryId) {
    _selectedCategoryId = categoryId;
    _applyCategoryFilter();
    notifyListeners();
  }

  void _applyCategoryFilter() {
    if (_selectedCategoryId == null || _selectedCategoryId == 'all') {
      _filteredNewsItems = List.from(_allNewsItems);
    } else {
      _filteredNewsItems = _allNewsItems.where((item) => item.category_id == _selectedCategoryId).toList();
    }
  }

  bool _prefetching = false;
  DateTime _lastPrefetch = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastPrefetchedEnd = 0;

  // Llamar cuando estés cerca del final del scroll
  Future<void> prefetchTail({int batch = 16}) async {
    if (_prefetching) return;
    if (DateTime.now().difference(_lastPrefetch).inMilliseconds < 1200) return;

    final list = _filteredNewsItems; // usa aquí el nombre real de tu lista
    if (list.isEmpty) return;

    final start = _lastPrefetchedEnd;
    final end = (start + batch > list.length) ? list.length : start + batch;
    if (start >= end) return;

    final urls = <String>[];
    for (var i = start; i < end; i++) {
      final u = list[i].image_url; // ajusta si tu modelo usa otro nombre
      if (u.isNotEmpty) urls.add(u);
    }
    if (urls.isEmpty) {
      _lastPrefetchedEnd = end;
      return;
    }

    _prefetching = true;
    try {
      await ImageCacheService.instance.prefetchUrls(
        urls,
        concurrency: 4,
        maxBytesBudget: 50 * 1024 * 1024,
        maxFilesBudget: 400,
      );
      _lastPrefetch = DateTime.now();
      _lastPrefetchedEnd = end;
    } finally {
      _prefetching = false;
    }
  }
}

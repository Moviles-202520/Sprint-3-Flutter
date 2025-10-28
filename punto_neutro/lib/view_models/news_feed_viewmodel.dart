import 'package:flutter/foundation.dart';
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
}
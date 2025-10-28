import '../../domain/models/category.dart';

class CategoriesRepository {
  // Hardcoded for now, could be loaded from Supabase or local DB
  static final List<Category> categories = [
    Category(category_id: '1', name: 'Politics'),
    Category(category_id: '2', name: 'Sports'),
    Category(category_id: '3', name: 'Science'),
    Category(category_id: '4', name: 'Economics'),
    Category(category_id: '5', name: 'Business'),
    Category(category_id: '6', name: 'Climate'),
    Category(category_id: '7', name: 'Conflict'),
    Category(category_id: '8', name: 'Local'),
  ];

  List<Category> getAllCategories() => categories;
}

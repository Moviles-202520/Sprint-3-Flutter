import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/hybrid_news_repository.dart';
import '../../domain/models/news_item.dart';

class SavedNewsScreen extends StatefulWidget {
  final HybridNewsRepository repo;
  const SavedNewsScreen({super.key, required this.repo});

  @override
  State<SavedNewsScreen> createState() => _SavedNewsScreenState();
}

class _SavedNewsScreenState extends State<SavedNewsScreen> {
  List<NewsItem> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<HybridNewsRepository>();
    final ids = (await repo.getBookmarkedIds()).toSet();
    final local = await repo.getNewsList(); // ya lo tienes en el híbrido
    items = local.where((n) => ids.contains(n.news_item_id)).toList();
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Guardados')),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) {
          final n = items[i];
          return ListTile(
            title: Text(n.title),
            subtitle: Text(n.short_description ?? ''),
            onTap: () {
              // Navega a detalle con n.newsItemId
            },
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:punto_neutro/presentation/viewmodels/auth_view_model.dart';
import 'package:punto_neutro/core/analytics_service.dart';
// repository imports are specific to providers
import 'package:punto_neutro/domain/models/news_item.dart';
import 'package:punto_neutro/view_models/news_feed_viewmodel.dart';
import 'package:punto_neutro/data/repositories/local_news_repository.dart';
import 'news_detail_screen.dart';
import '../../data/repositories/categories_repository.dart';
import '../widgets/weather_widget.dart';
import '../viewmodels/weather_viewmodel.dart';
import '../../data/services/weather_service.dart';
import '../../data/repositories/weather_repository.dart';
import '../../core/location_service.dart';
import 'analytics_dashboard_screen.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});
  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  bool _sessionStarted = false;

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScrollNearEnd);
    _scrollCtrl.dispose();
    super.dispose();

    // End session when leaving feed
    try {
      final vm = context.read<AuthViewModel>();
      if (vm.userProfileId != null) {
        AnalyticsService().endSession();
      }
    } catch (_) {}
    super.dispose();
  }

  // [ADD] dentro del _NewsFeedScreenState
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScrollNearEnd);
  }

// [ADD] dispara prefetch cuando falten ~800 px para el final
  void _onScrollNearEnd() {
    final pos = _scrollCtrl.position;
    if (!pos.hasPixels || !pos.hasContentDimensions) return;

    if (pos.pixels > (pos.maxScrollExtent - 800)) {
      // Índice aproximado del primer ítem visible (ajusta 220 si tus cards son más grandes/pequeñas)
      final firstVisibleApprox = (pos.pixels / 220).floor();

      // Llama al VM sin alterar tu flujo actual
      final vm = context.read<NewsFeedViewModel>();
      vm.prefetchTail(
        batch: 18, // próximas ~18 imágenes
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Crear WeatherService (pon tu API key aquí)
  final weatherService = WeatherService(apiKey: '44cbc6a126384edfba3161815251910');
    final weatherRepo = WeatherRepository(weatherService);

    return MultiProvider(
      providers: [
  ChangeNotifierProvider(create: (_) => NewsFeedViewModel(LocalNewsRepository())),
        ChangeNotifierProvider(create: (_) => WeatherViewModel(weatherRepo)),
      ],
      child: Builder(builder: (context) {
        // Cargar clima al abrir (usamos postFrameCallback para no notificar durante el build)
        final weatherVm = context.read<WeatherViewModel>();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!weatherVm.isLoading && weatherVm.data == null) {
            try {
              final pos = await LocationService.instance.getCurrentPosition();
              final q = '${pos.latitude},${pos.longitude}';
              weatherVm.loadWeather(q);
            } catch (e) {
              // fallback
              weatherVm.loadWeather('Bogota,CO');
            }
          }
        });

        // Start session once when entering feed
        final authVm = context.read<AuthViewModel>();
        if (!_sessionStarted && authVm.userProfileId != null) {
          _sessionStarted = true;
          AnalyticsService().startSession(authVm.userProfileId!);
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(context),
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final metrics = notification.metrics;
              if (metrics.pixels >= metrics.maxScrollExtent - 800) {
                // 🔥 Llama al método de prefetch en tu ViewModel
                context.read<NewsFeedViewModel>().prefetchTail(batch: 18);
              }
              return false; // No detiene el scroll normal
            },
            child: _buildBody(),
          ),
        );
      }),
    );
  }
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final categories = CategoriesRepository.categories;
    final vm = Provider.of<NewsFeedViewModel>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      leadingWidth: screenWidth * 0.35,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              isDense: true,
              dropdownColor: Colors.grey[900],
              value: vm.selectedCategoryId ?? 'all',
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
              style: TextStyle(
                color: Colors.white, 
                fontSize: screenWidth > 600 ? 15 : 13, 
                fontWeight: FontWeight.w600
              ),
              selectedItemBuilder: (context) {
                return [
                  const Center(child: Text('All Categories', style: TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
                  ...categories.map((cat) => Center(child: Text(cat.name, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis))),
                ];
              },
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('All Categories', style: TextStyle(color: Colors.white, fontSize: 16), overflow: TextOverflow.ellipsis),
                ),
                ...categories.map((cat) => DropdownMenuItem(
                  value: cat.category_id,
                  child: Row(
                    children: [
                      const Icon(Icons.label, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(cat.name, style: const TextStyle(color: Colors.white, fontSize: 16), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                )),
              ],
              onChanged: (value) {
                vm.setCategoryFilter(value == 'all' ? null : value);
                if (value != null && value != 'all') {
                  final id = int.tryParse(value);
                  if (id != null) {
                    AnalyticsService().trackFilterApplied(id);
                  }
                }
              },
            ),
          ),
        ),
      ),
      title: const Text(
        'For You',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'Dashboard',
          icon: const Icon(Icons.analytics_outlined, color: Colors.white),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AnalyticsDashboardScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Align(alignment: Alignment.centerRight, child: WeatherWidget(city: 'Bogota,CO')),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer<NewsFeedViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (viewModel.newsItems.isEmpty) {
          return const Center(
            child: Text(
              'No hay noticias disponibles',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return PageView.builder(
          itemCount: viewModel.newsItems.length,
          scrollDirection: Axis.vertical,
          onPageChanged: (index) {
            viewModel.setCurrentIndex(index);
            // track article viewed
            final news = viewModel.newsItems[index];
            // When scrolling the feed, only increment the article counter.
            // Do NOT record the session-category relation here — that should
            // only be recorded when the user clicks into the detail screen.
            AnalyticsService().incrementArticlesViewed(news.news_item_id);
            
            // Prefetch cuando estamos cerca del final (últimas 3 noticias)
            final threshold = 3;
            if (index >= viewModel.newsItems.length - threshold) {
              viewModel.prefetchTail(batch: 16);
            }
          },
          itemBuilder: (context, index) {
            final news = viewModel.newsItems[index];
            return _NewsItemCard(news: news, index: index);
          },
        );
      },
    );
  }

}

class _NewsItemCard extends StatelessWidget {
  final NewsItem news;
  final int index;

  const _NewsItemCard({
    required this.news,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Incrementar contador de artículos vistos and record category before navigation
        final catId = int.tryParse(news.category_id);
        try {
          await AnalyticsService().incrementArticlesViewed(news.news_item_id, catId);
        } catch (e) {
          print('⚠️ [UI] Error waiting for analytics increment: $e');
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewsDetailScreen(
              news_item_id: news.news_item_id,
              repository: LocalNewsRepository(),
            ),
          ),
        );
      },
      child: Stack(
        children: [
          // Fondo con imagen
          _buildBackground(),
          
          // Gradiente oscuro para mejor legibilidad
          _buildGradient(),
          
          // Contenido de la noticia
          _buildContent(context),
          
          // Sidebar con acciones
          _buildActionSidebar(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: news.image_url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: news.image_url,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade900,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white24,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) {
                return Container(color: Colors.grey.shade800);
              },
            )
          : Container(color: Colors.grey.shade800),
    );
  }

  Widget _buildGradient() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Positioned(
      left: 16,
      right: 80,
      bottom: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Categoría y score de confiabilidad
          _buildCategoryRow(),
          
          const SizedBox(height: 12),
          
          // Título
          Text(
            news.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 8),
          
          // Descripción corta
          Text(
            news.short_description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 12),
          
          // Autor y fecha
          _buildAuthorInfo(),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    final reliabilityPercent = (news.average_reliability_score * 100).round();
    final reliabilityColor = reliabilityPercent >= 80
        ? Colors.green
        : reliabilityPercent >= 60
            ? Colors.orange
            : Colors.red;

    return Row(
      children: [
        // Categoría
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _getCategoryName(news.category_id),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Score de confiabilidad
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: reliabilityColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 14,
                color: reliabilityColor,
              ),
              const SizedBox(width: 4),
              Text(
                '$reliabilityPercent%',
                style: TextStyle(
                  color: reliabilityColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorInfo() {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.white.withOpacity(0.2),
          child: Icon(
            news.is_recognized_author 
                ? Icons.verified_user 
                : Icons.person,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                news.author_institution,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatDate(news.publication_date),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionSidebar() {
  return Positioned(
    right: 16,
    bottom: 100,
    child: Column(
      children: [
        // Avatar del autor
        _buildAuthorAvatar(),
        
        const SizedBox(height: 20),
        
        // Acciones con números fijos por ahora
        _buildActionButton(Icons.favorite_border, '1.2K', () {}),
        _buildActionButton(Icons.comment_outlined, '348', () {}),
        _buildActionButton(Icons.bookmark_border, 'Guardar', () {}),
        _buildActionButton(Icons.share_outlined, 'Compartir', () {}),
        
        const SizedBox(height: 20),
        
        // Indicador de progreso
        _buildProgressIndicator(),
      ],
    ),
  );
}

  Widget _buildAuthorAvatar() {
    return Column(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.white.withOpacity(0.2),
          child: Icon(
            news.is_recognized_author 
                ? Icons.verified_user 
                : Icons.person,
            size: 30,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        const Icon(Icons.favorite, color: Colors.red, size: 16),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String text, VoidCallback onTap) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white, size: 28),
          onPressed: onTap,
        ),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Consumer<NewsFeedViewModel>(
      builder: (context, viewModel, child) {
        return Container(
          height: 60,
          width: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              // Progreso completado
              Container(
                height: (viewModel.currentIndex + 1) / viewModel.newsItems.length * 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getCategoryName(String categoryId) {
    final categories = {
      '1': 'Política',
      '2': 'Deportes', 
      '3': 'Ciencia',
      '4': 'Economía',
      '5': 'Negocios',
      '6': 'Clima',
      '7': 'Conflicto',
      '8': 'Local',
    };
    return categories[categoryId] ?? 'Noticias';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) return 'Ahora';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }
}
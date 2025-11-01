import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../view_models/analytics_dashboard_viewmodel.dart';

// Helper widget para las tarjetas de gráficas
class _ChartCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class AnalyticsDashboardScreen extends StatelessWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AnalyticsDashboardViewModel()..initializeDashboard(),
      child: Consumer<AnalyticsDashboardViewModel>(
        builder: (context, vm, _) {
          // Mostrar loading mientras carga
          if (vm.isLoading) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Analytics Dashboard'),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          // Mostrar error si hay
          if (vm.error != null) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Analytics Dashboard'),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text('Error: ${vm.error}', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            );
          }

          // Usar los nuevos datos del ViewModel para mostrar las BQ
          // BQ1: Personal Bias Score
          final personalBias = vm.personalBiasData;
          final userAvgBias = personalBias['user_avg_bias'] ?? 0.0;
          final communityAvgBias = personalBias['community_avg_bias'] ?? 0.0;

          // BQ2: Source Veracity
          final sourceData = vm.sourceVeracityData;

          // BQ3: Conversion Rate
          final conversionData = vm.conversionRateData;
          final conversionRate = conversionData['conversion_rate'] ?? 0.0;

          // BQ4: Category Distribution
          final categoryData = vm.categoryDistributionData;

          // BQ5: Engagement vs Accuracy
          final engagementData = vm.engagementAccuracyData;
          final correlation = engagementData['correlation'] ?? 0.0;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Analytics Dashboard'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // BQ1: Personal Bias Score - Gráfica de barras comparativa
                _ChartCard(
                  title: 'BQ1: Personal Bias Score',
                  description: 'Comparación entre tu promedio de confiabilidad y el de la comunidad (escala 0-1)',
                  child: Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            gridData: const FlGridData(show: true, drawVerticalLine: false),
                            alignment: BarChartAlignment.spaceAround,
                            minY: 0,
                            maxY: 1.0,
                            barGroups: [
                              BarChartGroupData(
                                x: 0,
                                barRods: [
                                  BarChartRodData(
                                    toY: userAvgBias,
                                    color: Colors.blue,
                                    width: 40,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  )
                                ],
                              ),
                              BarChartGroupData(
                                x: 1,
                                barRods: [
                                  BarChartRodData(
                                    toY: communityAvgBias,
                                    color: Colors.green,
                                    width: 40,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  )
                                ],
                              ),
                            ],
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toStringAsFixed(1),
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final style = const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    );
                                    switch (value.toInt()) {
                                      case 0:
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text('Tu promedio', style: style),
                                        );
                                      case 1:
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text('Comunidad', style: style),
                                        );
                                      default:
                                        return const SizedBox();
                                    }
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        userAvgBias > communityAvgBias
                            ? '📊 Tu evaluación promedio es ${userAvgBias.toStringAsFixed(2)}, mayor que el promedio comunitario (${communityAvgBias.toStringAsFixed(2)})'
                            : '📊 Tu evaluación promedio es ${userAvgBias.toStringAsFixed(2)}, menor o igual al promedio comunitario (${communityAvgBias.toStringAsFixed(2)})',
                        style: TextStyle(
                          color: userAvgBias > communityAvgBias ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // BQ2: Source Veracity - Gráfica de barras horizontales
                _ChartCard(
                  title: 'BQ2: Source Veracity Analysis',
                  description: 'Top 5 fuentes por confiabilidad promedio (escala 0-1)',
                  child: sourceData.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No hay datos disponibles',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : SizedBox(
                          height: 250,
                          child: BarChart(
                            BarChartData(
                              gridData: const FlGridData(show: true, drawVerticalLine: false),
                              alignment: BarChartAlignment.spaceAround,
                              minY: 0,
                              maxY: 1.0,
                              barGroups: sourceData
                                  .take(5)
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final idx = entry.key;
                                final source = entry.value;
                                final reliability = (source['avg_reliability'] as num).toDouble();
                                
                                return BarChartGroupData(
                                  x: idx,
                                  barRods: [
                                    BarChartRodData(
                                      toY: reliability,
                                      color: reliability >= 0.8
                                          ? Colors.green
                                          : reliability >= 0.6
                                              ? Colors.orange
                                              : Colors.red,
                                      width: 30,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    )
                                  ],
                                );
                              }).toList(),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toStringAsFixed(1),
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      );
                                    },
                                  ),
                                ),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 80,
                                    getTitlesWidget: (value, meta) {
                                      final sources = sourceData.take(5).toList();
                                      final idx = value.toInt();
                                      if (idx < 0 || idx >= sources.length) return const SizedBox();
                                      
                                      final sourceName = sources[idx]['source_name'] as String;
                                      final displayName = sourceName.length > 15
                                          ? '${sourceName.substring(0, 12)}...'
                                          : sourceName;
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          displayName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                ),

                // BQ3: Conversion Rate - Gráfica de dona/pie
                _ChartCard(
                  title: 'BQ3: Conversion Rate from Shared Articles',
                  description: 'Proporción de usuarios que hicieron ratings después de clicks en artículos compartidos',
                  child: Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: PieChart(
                                PieChartData(
                                  sections: [
                                    PieChartSectionData(
                                      value: (conversionData['rated_count'] ?? 0).toDouble(),
                                      title: '${((conversionRate * 100)).toStringAsFixed(1)}%',
                                      color: Colors.green,
                                      radius: 80,
                                      titleStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: ((conversionData['total_shared'] ?? 0) - (conversionData['rated_count'] ?? 0)).toDouble().clamp(0, double.infinity),
                                      title: '${(100 - (conversionRate * 100)).toStringAsFixed(1)}%',
                                      color: Colors.red.withOpacity(0.3),
                                      radius: 80,
                                      titleStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 0,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Convertidos',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'No convertidos',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      '${conversionData['total_shared'] ?? 0}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Total Compartidos',
                                      style: TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${conversionData['rated_count'] ?? 0}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Hicieron Rating',
                                      style: TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // BQ4: Category Distribution - Gráfica de barras
                _ChartCard(
                  title: 'BQ4: Rating Distribution by Category',
                  description: 'Cantidad de ratings por categoría',
                  child: categoryData.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No hay datos disponibles',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : SizedBox(
                          height: 250,
                          child: BarChart(
                            BarChartData(
                              gridData: const FlGridData(show: true, drawVerticalLine: false),
                              alignment: BarChartAlignment.spaceAround,
                              barGroups: categoryData
                                  .take(5)
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final idx = entry.key;
                                final cat = entry.value;
                                final count = (cat['rating_count'] as num).toDouble();
                                
                                return BarChartGroupData(
                                  x: idx,
                                  barRods: [
                                    BarChartRodData(
                                      toY: count,
                                      color: Colors.purple,
                                      width: 30,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    )
                                  ],
                                );
                              }).toList(),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      );
                                    },
                                  ),
                                ),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 80,
                                    getTitlesWidget: (value, meta) {
                                      final categories = categoryData.take(5).toList();
                                      final idx = value.toInt();
                                      if (idx < 0 || idx >= categories.length) return const SizedBox();
                                      
                                      final catName = categories[idx]['category_name'] as String;
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          catName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                ),

                // BQ5: Engagement vs Accuracy - Scatter plot simulado con indicadores
                _ChartCard(
                  title: 'BQ5: Engagement vs Accuracy Correlation',
                  description: 'Correlación de Pearson entre tiempo de engagement y precisión de ratings',
                  child: Column(
                    children: [
                      SizedBox(
                        height: 120,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                correlation.toStringAsFixed(3),
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: correlation > 0
                                      ? Colors.green
                                      : correlation < 0
                                          ? Colors.red
                                          : Colors.grey,
                                ),
                              ),
                              Text(
                                'Coeficiente de Pearson',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  correlation > 0
                                      ? Icons.trending_up
                                      : correlation < 0
                                          ? Icons.trending_down
                                          : Icons.trending_flat,
                                  color: correlation > 0
                                      ? Colors.green
                                      : correlation < 0
                                          ? Colors.red
                                          : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    correlation > 0.3
                                        ? 'Correlación positiva: Mayor engagement se asocia con mayor precisión'
                                        : correlation < -0.3
                                            ? 'Correlación negativa: Mayor engagement se asocia con menor precisión'
                                            : 'Correlación débil o nula: No hay relación clara',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Muestra: ${engagementData['sample_size'] ?? 0} usuarios',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            if (engagementData['avg_engagement'] != null)
                              Text(
                                'Engagement promedio: ${(engagementData['avg_engagement'] as num).toStringAsFixed(1)} puntos',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            if (engagementData['avg_accuracy'] != null)
                              Text(
                                'Precisión promedio: ${(engagementData['avg_accuracy'] as num).toStringAsFixed(3)}/1.0',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

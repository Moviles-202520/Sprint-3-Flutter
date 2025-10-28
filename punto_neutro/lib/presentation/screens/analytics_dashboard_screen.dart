import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../view_models/analytics_dashboard_viewmodel.dart';

// Helper widgets for charts
class TimeWindowData extends StatelessWidget {
  final String label;
  final double avg;
  final int count;
  final Color color;

  const TimeWindowData(this.label, this.avg, this.count, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        Text(avg.toStringAsFixed(2), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text('(n=$count)', style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String description;
  final String xLabel;
  final String yLabel;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.description,
    required this.xLabel,
    required this.yLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            child,
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Eje Y: $yLabel', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text('Eje X: $xLabel', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
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
      create: (_) => AnalyticsDashboardViewModel(),
      child: Consumer<AnalyticsDashboardViewModel>(
        builder: (context, vm, _) {
          // Si no hay datos aún, mostrar loading
          if (vm.ratings.isEmpty && vm.commentsCompleted.isEmpty && vm.commentsStarted.isEmpty && vm.engagementEvents.isEmpty && vm.userSessions.isEmpty) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Analytics Dashboard'),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          // BQ1: Funnel de Comentarios y Ratings
          final commentStarted = vm.commentsStarted.length;
          final commentCompleted = vm.commentsCompleted.length;
          final ratingCompleted = vm.ratings.length;
          // Para ratingStarted, contar engagementEvents tipo rating/started
          final ratingStarted = vm.engagementEvents.where((e) => e['event_type'] == 'rating' && e['action'] == 'started').length;

          // BQ2: Duración promedio de sesión
          final sessions = vm.userSessions.where((s) => s['end_time'] != null && s['start_time'] != null).map((s) {
            final Map<String, dynamic> m = Map<String, dynamic>.from(s);
            if (m['duration_seconds'] == null) {
              try {
                final start = DateTime.parse(m['start_time'].toString());
                final end = DateTime.parse(m['end_time'].toString());
                m['duration_seconds'] = end.difference(start).inSeconds;
              } catch (_) {
                m['duration_seconds'] = 0;
              }
            }
            return m;
          }).toList();

          // BQ2: Con/sin filtros
          final sessionsWithFilter = sessions.where((s) => s['used_category_filter'] == true).toList();
          final sessionsWithoutFilter = sessions.where((s) => s['used_category_filter'] == false).toList();
          final avgWithFilter = sessionsWithFilter.isEmpty ? 0.0 : sessionsWithFilter.map((s) => (s['duration_seconds'] ?? 0) as num).reduce((a, b) => a + b).toDouble() / sessionsWithFilter.length;
          final avgWithoutFilter = sessionsWithoutFilter.isEmpty ? 0.0 : sessionsWithoutFilter.map((s) => (s['duration_seconds'] ?? 0) as num).reduce((a, b) => a + b).toDouble() / sessionsWithoutFilter.length;
          final sessionsWithFilterCount = sessionsWithFilter.length;
          final sessionsWithoutFilterCount = sessionsWithoutFilter.length;
          final sessionsCount = sessions.length;

          // BQ3/BQ4: ratings y polarización (simplificado para tiempo real)
          final polarization = <String, double>{};
          final ratingsByArticle = <String, Map<String, double>>{};

          // BQ5: Duración promedio por dispositivo/SO
          final avgSessionByDevice = <String, double>{};
          final avgSessionByOS = <String, double>{};
          for (var s in sessions) {
            final device = s['device_type']?.toString() ?? 'unknown';
            final os = s['operating_system']?.toString() ?? 'Unknown';
            final dur = (s['duration_seconds'] ?? 0) as num;
            avgSessionByDevice[device] = ((avgSessionByDevice[device] ?? 0) + dur) / 2;
            avgSessionByOS[os] = ((avgSessionByOS[os] ?? 0) + dur) / 2;
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('Analytics Dashboard'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // BQ1: Funnel de Comentarios y Ratings
                _ChartCard(
                  title: 'BQ1: Funnel de Comentarios y Ratings',
                  description: 'Comparativo de eventos iniciados vs completados. Muestra tasa de conversión.',
                  xLabel: 'Tipo/Estado',
                  yLabel: 'Cantidad de eventos',
                  child: SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        gridData: FlGridData(show: true, drawVerticalLine: false),
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: [
                          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: commentStarted.toDouble(), color: Colors.blue, width: 20)]),
                          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: commentCompleted.toDouble(), color: Colors.green, width: 20)]),
                          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: ratingStarted.toDouble(), color: Colors.orange, width: 20)]),
                          BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: ratingCompleted.toDouble(), color: Colors.purple, width: 20)]),
                        ],
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 60,
                              getTitlesWidget: (value, meta) {
                                final style = TextStyle(fontSize: 10, fontWeight: FontWeight.bold);
                                switch (value.toInt()) {
                                  case 0:
                                    return Padding(padding: EdgeInsets.only(top: 8), child: Text('Comment\nStarted', style: style));
                                  case 1:
                                    return Padding(padding: EdgeInsets.only(top: 8), child: Text('Comment\nCompleted', style: style));
                                  case 2:
                                    return Padding(padding: EdgeInsets.only(top: 8), child: Text('Rating\nStarted', style: style));
                                  case 3:
                                    return Padding(padding: EdgeInsets.only(top: 8), child: Text('Rating\nCompleted', style: style));
                                  default:
                                    return const Text('');
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          
          // Tasas de conversión
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tasas de Conversión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Builder(builder: (context) {
                    final total = commentStarted + commentCompleted;
                    final pct = total > 0 ? (commentCompleted / total * 100).clamp(0, 100) : 0;
                    return Text('• Comentarios: $commentCompleted completados de $total eventos (${pct.toStringAsFixed(1)}%)');
                  }),
                  Builder(builder: (context) {
                    final total = ratingStarted + ratingCompleted;
                    final pct = total > 0 ? (ratingCompleted / total * 100).clamp(0, 100) : 0;
                    return Text('• Ratings: $ratingCompleted completados de $total eventos (${pct.toStringAsFixed(1)}%)');
                  }),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // BQ2: Duración de sesión con/sin filtros
          _ChartCard(
            title: 'BQ2: Duración de Sesión con/sin Filtros',
            description: 'Comparación de duración promedio cuando se usa filtro de categoría vs sin filtro.',
            xLabel: 'Uso de filtro',
            yLabel: 'Segundos promedio',
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      gridData: FlGridData(show: true),
                      alignment: BarChartAlignment.spaceAround,
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [BarChartRodData(toY: avgWithFilter, color: Colors.blue, width: 40)],
                        ),
                        BarChartGroupData(
                          x: 1,
                          barRods: [BarChartRodData(toY: avgWithoutFilter, color: Colors.red, width: 40)],
                        ),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              switch (value.toInt()) {
                                case 0:
                                  return Text('Con Filtro\n(n=$sessionsWithFilterCount)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12));
                                case 1:
                                  return Text('Sin Filtro\n(n=$sessionsWithoutFilterCount)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Diferencia: ${(avgWithFilter - avgWithoutFilter).toStringAsFixed(0)}s (${((avgWithFilter - avgWithoutFilter) * 100 / (avgWithoutFilter > 0 ? avgWithoutFilter : 1)).toStringAsFixed(1)}%)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (sessionsCount == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Sin datos de sesiones. Verifica permisos RLS para SELECT en user_sessions (ver script 2025-10-24_open_select_for_analytics.sql).',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // BQ3: Polarización por categoría
          _ChartCard(
            title: 'BQ3: Polarización de Ratings por Categoría',
            description: 'Desviación estándar de los puntajes por categoría. Mayor valor = opiniones más divididas.',
            xLabel: 'Categoría',
            yLabel: 'Desviación estándar',
            child: polarization.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: Text('Sin datos de ratings'))
                : SizedBox(
                    height: 240,
                    child: BarChart(
                      BarChartData(
                        gridData: FlGridData(show: true),
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: [
                          for (var i = 0; i < polarization.entries.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [BarChartRodData(toY: polarization.values.elementAt(i), color: Colors.orange, width: 25)],
                            ),
                        ],
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 60,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() < 0 || value.toInt() >= polarization.length) return const SizedBox();
                                final cat = polarization.keys.elementAt(value.toInt());
                                return Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(cat, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10)),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          
          const SizedBox(height: 16),
          
          // BQ4: Evolución de ratings por artículo
          _ChartCard(
            title: 'BQ4: Evolución de Ratings por Artículo',
            description: 'Cómo cambian los ratings promedio en diferentes ventanas de tiempo desde publicación.',
            xLabel: 'Artículo',
            yLabel: 'Rating promedio',
            child: ratingsByArticle.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: Text('Sin datos de ratings por artículo'))
                : Column(
                    children: [
                      SizedBox(
                        height: 300,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: ratingsByArticle.length > 5 ? 5 : ratingsByArticle.length,
                          itemBuilder: (context, index) {
                            final entry = ratingsByArticle.entries.elementAt(index);
                            final article = entry.key;
                            final data = entry.value;
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(article.length > 40 ? '${article.substring(0, 40)}...' : article, 
                                         style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        TimeWindowData('24h', data['first_24h_avg']!, data['first_24h_count']!.toInt(), Colors.blue),
                                        TimeWindowData('1 semana', data['first_week_avg']!, data['first_week_count']!.toInt(), Colors.green),
                                        TimeWindowData('Total', data['all_time_avg']!, data['all_time_count']!.toInt(), Colors.purple),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (ratingsByArticle.length > 5)
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('... y ${ratingsByArticle.length - 5} artículos más', style: TextStyle(fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
          ),
          
          const SizedBox(height: 16),
          
          // BQ5: Duración por dispositivo
          _ChartCard(
            title: 'BQ5: Duración Promedio por Dispositivo',
            description: 'Promedio en segundos por tipo de dispositivo.',
            xLabel: 'Dispositivo',
            yLabel: 'Segundos',
            child: avgSessionByDevice.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Sin datos de sesiones por dispositivo. Si persiste, revisa permisos RLS (SELECT en user_sessions).'),
                  )
                : SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        gridData: FlGridData(show: true),
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: () {
                          final entries = avgSessionByDevice.entries.toList();
                          return [
                            for (var i = 0; i < entries.length; i++)
                              BarChartGroupData(
                                x: i,
                                barRods: [BarChartRodData(toY: entries[i].value, color: Colors.purple, width: 30)],
                              ),
                          ];
                        }(),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final entries = avgSessionByDevice.keys.toList();
                                final idx = value.toInt();
                                if (idx < 0 || idx >= entries.length) return const SizedBox();
                                return Text(entries[idx], overflow: TextOverflow.ellipsis);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          
          const SizedBox(height: 16),
          
          // BQ5 adicional: Duración por Sistema Operativo
          _ChartCard(
            title: 'BQ5: Duración Promedio por Sistema Operativo',
            description: 'Promedio en segundos por SO (top 10).',
            xLabel: 'Sistema Operativo',
            yLabel: 'Segundos',
            child: avgSessionByOS.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Sin datos de sesiones por SO. Si persiste, revisa permisos RLS (SELECT en user_sessions).'),
                  )
                : SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        gridData: FlGridData(show: true),
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: () {
                          final entries = avgSessionByOS.entries.take(10).toList();
                          return [
                            for (var i = 0; i < entries.length; i++)
                              BarChartGroupData(
                                x: i,
                                barRods: [BarChartRodData(toY: entries[i].value, color: Colors.teal, width: 20)],
                              ),
                          ];
                        }(),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 80,
                              getTitlesWidget: (value, meta) {
                                final entries = avgSessionByOS.entries.take(10).toList();
                                final idx = value.toInt();
                                if (idx < 0 || idx >= entries.length) return const SizedBox();
                                return Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    entries[idx].key,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 9),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
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

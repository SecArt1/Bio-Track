import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:bio_track/l10n/language_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';

class PreviousResultsPage extends StatefulWidget {
  const PreviousResultsPage({Key? key}) : super(key: key);

  @override
  _PreviousResultsPageState createState() => _PreviousResultsPageState();
}

class _PreviousResultsPageState extends State<PreviousResultsPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _results = [];
  String _selectedFilter = 'all'; // 'all', 'week', 'month', 'year'
  String _selectedMetric = 'all'; // 'all', 'heart_rate', 'blood_pressure', etc.
  TabController? _tabController;
  bool _showChart = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadResults();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Query Firestore for test results
      final QuerySnapshot resultsSnapshot = await FirebaseFirestore.instance
          .collection('healthMetrics')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      // Filter results based on selected filter
      List<Map<String, dynamic>> filteredResults = [];

      for (var doc in resultsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final DateTime timestamp = (data['timestamp'] as Timestamp).toDate();
        final now = DateTime.now();

        bool includeResult = false;

        // Apply time filter
        switch (_selectedFilter) {
          case 'week':
            includeResult =
                timestamp.isAfter(now.subtract(const Duration(days: 7)));
            break;
          case 'month':
            includeResult =
                timestamp.isAfter(DateTime(now.year, now.month - 1, now.day));
            break;
          case 'year':
            includeResult =
                timestamp.isAfter(DateTime(now.year - 1, now.month, now.day));
            break;
          default: // 'all'
            includeResult = true;
        }

        // Apply metric filter
        if (includeResult && _selectedMetric != 'all') {
          includeResult = data['type'] == _selectedMetric;
        }

        if (includeResult) {
          filteredResults.add({
            'id': doc.id,
            ...data,
          });
        }
      }

      if (mounted) {
        setState(() {
          _results = filteredResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading results: $e')),
        );
      }
      print('Error loading results: $e');
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy - HH:mm').format(date);
  }

  // Generate chart data for the selected metric
  List<FlSpot> _generateChartData(String metric) {
    List<FlSpot> spots = [];

    // Filter results for the selected metric
    final List<Map<String, dynamic>> filteredResults = _selectedMetric == 'all'
        ? _results
        : _results
            .where((result) => result['type'] == _selectedMetric)
            .toList();

    // Sort by timestamp (oldest first)
    filteredResults.sort((a, b) {
      final aTime = (a['timestamp'] as Timestamp).toDate();
      final bTime = (b['timestamp'] as Timestamp).toDate();
      return aTime.compareTo(bTime);
    });

    // Get the earliest date to calculate X-axis
    final DateTime firstDate = filteredResults.isNotEmpty
        ? (filteredResults.first['timestamp'] as Timestamp).toDate()
        : DateTime.now();

    // Create spots for chart
    for (int i = 0; i < filteredResults.length; i++) {
      final result = filteredResults[i];
      final DateTime date = (result['timestamp'] as Timestamp).toDate();
      final double xValue = date.difference(firstDate).inDays.toDouble();

      // Get y value based on the metric
      double yValue = 0;
      if (result.containsKey('value')) {
        yValue = (result['value'] as num).toDouble();
      }

      spots.add(FlSpot(xValue, yValue));
    }

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          localizations.translate('previous_results'),
          style: const TextStyle(color: Color(0xff0383c2)),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xff0383c2)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xff0383c2),
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: localizations.translate('list_view')),
            Tab(text: localizations.translate('chart_view')),
            Tab(text: localizations.translate('summary')),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Time filter dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: localizations.translate('time_period'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    value: _selectedFilter,
                    items: [
                      DropdownMenuItem(
                          value: 'all',
                          child: Text(localizations.translate('all_time'))),
                      DropdownMenuItem(
                          value: 'week',
                          child: Text(localizations.translate('last_week'))),
                      DropdownMenuItem(
                          value: 'month',
                          child: Text(localizations.translate('last_month'))),
                      DropdownMenuItem(
                          value: 'year',
                          child: Text(localizations.translate('last_year'))),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedFilter = value;
                        });
                        _loadResults();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Metric filter dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: localizations.translate('measurement_type'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    value: _selectedMetric,
                    items: [
                      DropdownMenuItem(
                          value: 'all',
                          child: Text(localizations.translate('all_metrics'))),
                      DropdownMenuItem(
                          value: 'heart_rate',
                          child: Text(localizations.translate('heart_rate'))),
                      DropdownMenuItem(
                          value: 'blood_pressure',
                          child:
                              Text(localizations.translate('blood_pressure'))),
                      DropdownMenuItem(
                          value: 'weight',
                          child: Text(localizations.translate('weight'))),
                      DropdownMenuItem(
                          value: 'blood_sugar',
                          child: Text(localizations.translate('blood_sugar'))),
                      DropdownMenuItem(
                          value: 'oxygen',
                          child: Text(localizations.translate('oxygen'))),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedMetric = value;
                        });
                        _loadResults();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xff0383c2)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // List view
                      _results.isEmpty
                          ? _buildEmptyState(localizations)
                          : _buildListView(localizations),

                      // Chart view
                      _results.isEmpty
                          ? _buildEmptyState(localizations)
                          : _buildChartView(localizations),

                      // Summary view
                      _buildSummaryView(localizations),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff0383c2),
        onPressed: () {
          _loadResults();
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations localizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            localizations.translate('no_results_found'),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizations.translate('try_different_filters'),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildListView(AppLocalizations localizations) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        final DateTime timestamp = (result['timestamp'] as Timestamp).toDate();

        // Determine icon and color based on metric type
        IconData icon;
        Color color;
        String metric = result['type'] ?? 'unknown';

        switch (metric) {
          case 'heart_rate':
            icon = Icons.favorite;
            color = Colors.redAccent;
            break;
          case 'blood_pressure':
            icon = Icons.health_and_safety;
            color = Colors.blueAccent;
            break;
          case 'weight':
            icon = Icons.monitor_weight;
            color = Colors.orangeAccent;
            break;
          case 'blood_sugar':
            icon = Icons.bloodtype;
            color = Colors.purpleAccent;
            break;
          case 'oxygen':
            icon = Icons.air;
            color = Colors.cyan;
            break;
          default:
            icon = Icons.analytics;
            color = Colors.grey;
        }

        // Format the measurement value
        String value = '${result['value'] ?? 'N/A'}';
        String unit = '';

        switch (metric) {
          case 'heart_rate':
            unit = ' bpm';
            break;
          case 'blood_pressure':
            value =
                '${result['systolic'] ?? 'N/A'}/${result['diastolic'] ?? 'N/A'}';
            unit = ' mmHg';
            break;
          case 'weight':
            unit = ' kg';
            break;
          case 'blood_sugar':
            unit = ' mg/dL';
            break;
          case 'oxygen':
            unit = ' %';
            break;
        }

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              _showResultDetails(result);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon and date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color.withOpacity(0.2),
                            child: Icon(icon, color: color),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations.translate(metric),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _formatDate(timestamp),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$value$unit',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Additional details if any
                  if (result.containsKey('notes') && result['notes'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${result['notes']}',
                        style: TextStyle(
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartView(AppLocalizations localizations) {
    // Filter results for the selected metric
    final List<Map<String, dynamic>> chartData = _selectedMetric == 'all'
        ? _results
            .where((r) => r['type'] == 'heart_rate')
            .toList() // Default to heart_rate if 'all'
        : _results.where((r) => r['type'] == _selectedMetric).toList();

    if (chartData.isEmpty) {
      return Center(
        child: Text(
          localizations.translate('no_data_for_selected_metric'),
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    final spots = _generateChartData(_selectedMetric);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.translate(_selectedMetric == 'all'
                ? 'heart_rate_over_time'
                : '${_selectedMetric}_over_time'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizations.translate('tap_on_chart_for_details'),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: spots.isNotEmpty
                ? LineChart(
                    LineChartData(
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                            return touchedBarSpots.map((barSpot) {
                              final flSpot = barSpot;
                              final textStyle = TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              );
                              return LineTooltipItem(
                                '${flSpot.y.toStringAsFixed(1)}',
                                textStyle,
                              );
                            }).toList();
                          },
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                        ),
                        handleBuiltInTouches: true,
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: 1,
                        verticalInterval: 1,
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: Color(0xff68737d),
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: Color(0xff68737d),
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                            reservedSize: 40,
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: const Color(0xff37434d)),
                      ),
                      minX: 0,
                      maxX: spots.isEmpty ? 0 : spots.last.x,
                      minY: spots.isEmpty
                          ? 0
                          : spots
                                  .map((e) => e.y)
                                  .reduce((a, b) => a < b ? a : b) *
                              0.9,
                      maxY: spots.isEmpty
                          ? 0
                          : spots
                                  .map((e) => e.y)
                                  .reduce((a, b) => a > b ? a : b) *
                              1.1,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: const Color(0xff0383c2),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xff0383c2).withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Text(
                      localizations.translate('insufficient_data_for_chart'),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryView(AppLocalizations localizations) {
    if (_results.isEmpty) {
      return _buildEmptyState(localizations);
    }

    // Calculate statistics
    Map<String, Map<String, dynamic>> stats = {};

    // Process results to calculate stats
    for (var result in _results) {
      final String type = result['type'] ?? 'unknown';

      if (!stats.containsKey(type)) {
        stats[type] = {
          'count': 0,
          'min': double.infinity,
          'max': double.negativeInfinity,
          'sum': 0.0,
          'values': <double>[],
          'latest': null,
          'latest_date': null,
        };
      }

      if (result.containsKey('value') && result['value'] != null) {
        double value = (result['value'] as num).toDouble();
        stats[type]!['count'] = stats[type]!['count']! + 1;
        stats[type]!['min'] =
            value < stats[type]!['min'] ? value : stats[type]!['min'];
        stats[type]!['max'] =
            value > stats[type]!['max'] ? value : stats[type]!['max'];
        stats[type]!['sum'] = stats[type]!['sum'] + value;
        (stats[type]!['values'] as List<double>).add(value);

        // Track latest reading
        DateTime timestamp = (result['timestamp'] as Timestamp).toDate();
        if (stats[type]!['latest_date'] == null ||
            timestamp.isAfter(stats[type]!['latest_date'])) {
          stats[type]!['latest'] = value;
          stats[type]!['latest_date'] = timestamp;
        }
      }
    }

    // Calculate averages and medians
    stats.forEach((key, value) {
      if (value['count'] > 0) {
        value['average'] = value['sum'] / value['count'];

        List<double> values = List<double>.from(value['values']);
        values.sort();

        if (values.isNotEmpty) {
          int mid = values.length ~/ 2;
          value['median'] = values.length.isOdd
              ? values[mid]
              : (values[mid - 1] + values[mid]) / 2;
        }
      }
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.translate('summary_statistics'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${localizations.translate('total_measurements')}: ${_results.length}',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  '${localizations.translate('date_range')}: ${_results.isNotEmpty ? _formatDate((_results.last['timestamp'] as Timestamp).toDate()) : '-'} - ${_results.isNotEmpty ? _formatDate((_results.first['timestamp'] as Timestamp).toDate()) : '-'}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Generate a card for each metric type
        ...stats.entries.map((entry) {
          final String metricType = entry.key;
          final data = entry.value;

          // Skip if no readings
          if (data['count'] == 0) {
            return const SizedBox.shrink();
          }

          // Determine color and icon
          IconData icon;
          Color color;

          switch (metricType) {
            case 'heart_rate':
              icon = Icons.favorite;
              color = Colors.redAccent;
              break;
            case 'blood_pressure':
              icon = Icons.health_and_safety;
              color = Colors.blueAccent;
              break;
            case 'weight':
              icon = Icons.monitor_weight;
              color = Colors.orangeAccent;
              break;
            case 'blood_sugar':
              icon = Icons.bloodtype;
              color = Colors.purpleAccent;
              break;
            case 'oxygen':
              icon = Icons.air;
              color = Colors.cyan;
              break;
            default:
              icon = Icons.analytics;
              color = Colors.grey;
          }

          // Unit to display
          String unit = '';
          switch (metricType) {
            case 'heart_rate':
              unit = ' bpm';
              break;
            case 'blood_pressure':
              unit = ' mmHg';
              break;
            case 'weight':
              unit = ' kg';
              break;
            case 'blood_sugar':
              unit = ' mg/dL';
              break;
            case 'oxygen':
              unit = ' %';
              break;
          }

          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon and metric name
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withOpacity(0.2),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        localizations.translate(metricType),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Latest reading
                  if (data['latest'] != null) ...[
                    Text(
                      localizations.translate('latest_reading'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${data['latest']}$unit',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(data['latest_date']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Statistics grid
                  Row(
                    children: [
                      Expanded(
                        child: _statBox(
                          localizations.translate('average'),
                          '${data['average']?.toStringAsFixed(1) ?? 'N/A'}$unit',
                          color.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statBox(
                          localizations.translate('median'),
                          '${data['median']?.toStringAsFixed(1) ?? 'N/A'}$unit',
                          color.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _statBox(
                          localizations.translate('minimum'),
                          '${data['min'] == double.infinity ? 'N/A' : data['min'].toStringAsFixed(1)}$unit',
                          color.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statBox(
                          localizations.translate('maximum'),
                          '${data['max'] == double.negativeInfinity ? 'N/A' : data['max'].toStringAsFixed(1)}$unit',
                          color.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _statBox(
                    localizations.translate('total_readings'),
                    '${data['count']}',
                    color.withOpacity(0.8),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showResultDetails(Map<String, dynamic> result) {
    final DateTime timestamp = (result['timestamp'] as Timestamp).toDate();
    final localizations = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 5,
                  width: 40,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Text(
                localizations.translate('measurement_details'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Type and date
              InfoRow(
                label: localizations.translate('type'),
                value: localizations.translate(result['type'] ?? 'unknown'),
              ),
              const SizedBox(height: 8),
              InfoRow(
                label: localizations.translate('date'),
                value: _formatDate(timestamp),
              ),
              const SizedBox(height: 8),

              // Value based on type
              _buildValueDisplay(result, localizations),

              // Notes if available
              if (result.containsKey('notes') && result['notes'] != null) ...[
                const SizedBox(height: 16),
                Text(
                  localizations.translate('notes'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(result['notes']),
                ),
              ],

              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: Text(localizations.translate('share')),
                    onPressed: () {
                      // Share functionality
                      Navigator.pop(context);
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: Text(localizations.translate('delete')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      _confirmDeleteResult(result);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildValueDisplay(
      Map<String, dynamic> result, AppLocalizations localizations) {
    final String type = result['type'] ?? 'unknown';

    switch (type) {
      case 'heart_rate':
        return InfoRow(
          label: localizations.translate('heart_rate'),
          value: '${result['value']} bpm',
          valueColor: Colors.redAccent,
        );

      case 'blood_pressure':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(
              label: localizations.translate('systolic'),
              value: '${result['systolic']} mmHg',
              valueColor: Colors.blueAccent,
            ),
            const SizedBox(height: 8),
            InfoRow(
              label: localizations.translate('diastolic'),
              value: '${result['diastolic']} mmHg',
              valueColor: Colors.blueAccent,
            ),
          ],
        );

      case 'weight':
        return InfoRow(
          label: localizations.translate('weight'),
          value: '${result['value']} kg',
          valueColor: Colors.orangeAccent,
        );

      case 'blood_sugar':
        return InfoRow(
          label: localizations.translate('blood_sugar'),
          value: '${result['value']} mg/dL',
          valueColor: Colors.purpleAccent,
        );

      case 'oxygen':
        return InfoRow(
          label: localizations.translate('oxygen_saturation'),
          value: '${result['value']} %',
          valueColor: Colors.cyan,
        );

      default:
        return InfoRow(
          label: localizations.translate('value'),
          value: '${result['value'] ?? 'N/A'}',
        );
    }
  }

  void _confirmDeleteResult(Map<String, dynamic> result) {
    final localizations = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(localizations.translate('confirm_delete')),
          content: Text(localizations.translate('delete_result_confirmation')),
          actions: [
            TextButton(
              child: Text(localizations.translate('cancel')),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text(
                localizations.translate('delete'),
                style: const TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close bottom sheet

                try {
                  await FirebaseFirestore.instance
                      .collection('healthMetrics')
                      .doc(result['id'])
                      .delete();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text(localizations.translate('result_deleted'))),
                  );

                  // Reload results
                  _loadResults();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

// Helper widget for displaying info rows
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({
    Key? key,
    required this.label,
    required this.value,
    this.valueColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

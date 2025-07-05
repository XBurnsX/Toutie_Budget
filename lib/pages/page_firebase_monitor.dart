import 'package:flutter/material.dart';
import '../services/firebase_monitor_service.dart';

class PageFirebaseMonitor extends StatefulWidget {
  const PageFirebaseMonitor({super.key});

  @override
  State<PageFirebaseMonitor> createState() => _PageFirebaseMonitorState();
}

class _PageFirebaseMonitorState extends State<PageFirebaseMonitor>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  Map<String, dynamic> _globalStats = {};
  Map<String, dynamic> _todayStats = {};
  List<Map<String, dynamic>> _weeklyStats = [];
  List<Map<String, dynamic>> _history = [];
  List<MapEntry<String, int>> _topCollections = [];
  Map<String, int> _hourlyStats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _globalStats = await FirebaseMonitorService.getGlobalStats();
      _todayStats = await FirebaseMonitorService.getTodayStats();
      _weeklyStats = await FirebaseMonitorService.getLast7DaysStats();
      _history = await FirebaseMonitorService.getHistory();
      _topCollections = await FirebaseMonitorService.getTopCollections();
      _hourlyStats = await FirebaseMonitorService.getHourlyStats();

      // Trier l'historique par date (plus récent en premier)
      _history.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    } catch (e) {
      // Ignorer les erreurs
    }

    setState(() => _isLoading = false);
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider l\'historique'),
        content: const Text(
            'Êtes-vous sûr de vouloir supprimer tout l\'historique des requêtes ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseMonitorService.clearHistory();
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Historique supprimé')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Firebase'),
        backgroundColor: const Color(0xFF18191A),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: const Color(0xFF18191A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearHistory,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Aujourd\'hui'),
            Tab(text: 'Semaine'),
            Tab(text: 'Global'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTab(),
                _buildWeeklyTab(),
                _buildGlobalTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildTodayTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTodayStatsCard(),
            const SizedBox(height: 16),
            _buildTodayCollectionsCard(),
            const SizedBox(height: 16),
            _buildHourlyChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStatsCard() {
    return Card(
      color: const Color(0xFF313334),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.today,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Aujourd\'hui (${_todayStats['date'] ?? 'N/A'})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildStatItem(
                        'Lectures', _todayStats['reads'] ?? 0, Colors.blue)),
                Expanded(
                    child: _buildStatItem(
                        'Écritures', _todayStats['writes'] ?? 0, Colors.green)),
                Expanded(
                    child: _buildStatItem('Suppressions',
                        _todayStats['deletes'] ?? 0, Colors.red)),
                Expanded(
                    child: _buildStatItem('Requêtes',
                        _todayStats['queries'] ?? 0, Colors.orange)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildStatItem('Cache Hits',
                        _todayStats['cacheHits'] ?? 0, Colors.purple)),
                Expanded(
                    child: _buildStatItem('Cache Miss',
                        _todayStats['cacheMisses'] ?? 0, Colors.amber)),
                Expanded(
                    child: _buildStatItem(
                        'Taux Cache',
                        (_todayStats['cacheHitRate'] ?? 0.0).round(),
                        Colors.teal)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Total: ${_todayStats['total'] ?? 0} opérations',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCollectionsCard() {
    final collectionStats =
        _todayStats['collectionStats'] as Map<String, int>? ?? {};
    final sortedCollections = collectionStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      color: const Color(0xFF313334),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.collections,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Collections utilisées aujourd\'hui',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...sortedCollections.take(5).map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      Text(
                        '${entry.value}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeeklyStatsCard(),
            const SizedBox(height: 16),
            _buildWeeklyChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyStatsCard() {
    final totalWeekly =
        _weeklyStats.fold<int>(0, (sum, day) => sum + (day['total'] as int));

    return Card(
      color: const Color(0xFF313334),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_view_week,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  '7 derniers jours',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Total: $totalWeekly opérations',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Card(
      color: const Color(0xFF313334),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Évolution quotidienne',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _weeklyStats.map((day) {
                  final total = day['total'] as int;
                  final maxTotal = _weeklyStats
                      .map((d) => d['total'] as int)
                      .reduce((a, b) => a > b ? a : b);
                  final height = maxTotal > 0 ? (total / maxTotal) * 150 : 0.0;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 30,
                        height: height,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        day['dayName'] as String,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        '${day['total']}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGlobalStatsCard(),
            const SizedBox(height: 16),
            _buildTopCollectionsCard(),
            const SizedBox(height: 16),
            _buildHourlyChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalStatsCard() {
    return Card(
      color: const Color(0xFF313334),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Statistiques globales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildStatItem('Lectures',
                        _globalStats['totalReads'] ?? 0, Colors.blue)),
                Expanded(
                    child: _buildStatItem('Écritures',
                        _globalStats['totalWrites'] ?? 0, Colors.green)),
                Expanded(
                    child: _buildStatItem('Suppressions',
                        _globalStats['totalDeletes'] ?? 0, Colors.red)),
                Expanded(
                    child: _buildStatItem('Requêtes',
                        _globalStats['totalQueries'] ?? 0, Colors.orange)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Total: ${_globalStats['totalOperations'] ?? 0} opérations',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCollectionsCard() {
    return Card(
      color: const Color(0xFF313334),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Collections les plus utilisées',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._topCollections.take(10).map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${entry.value}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyChart() {
    final sortedHours = _hourlyStats.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      color: const Color(0xFF313334),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activité par heure',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: sortedHours.map((hour) {
                  final count = hour.value;
                  final maxCount =
                      _hourlyStats.values.reduce((a, b) => a > b ? a : b);
                  final height = maxCount > 0 ? (count / maxCount) * 100 : 0.0;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 20,
                        height: height,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${hour.key}h',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _history.isEmpty
          ? const Center(
              child: Text(
                'Aucun historique disponible',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final entry = _history[index];
                return _buildHistoryItem(entry);
              },
            ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> entry) {
    final type = entry['type'] as String;
    final collection = entry['collection'] as String;
    final document = entry['document'] as String;
    final count = entry['count'] as int;
    final time = entry['time'] as String;
    final details = entry['details'] as String?;

    Color typeColor;
    IconData typeIcon;

    switch (type) {
      case 'read':
        typeColor = Colors.blue;
        typeIcon = Icons.visibility;
        break;
      case 'write':
        typeColor = Colors.green;
        typeIcon = Icons.edit;
        break;
      case 'delete':
        typeColor = Colors.red;
        typeIcon = Icons.delete;
        break;
      case 'query':
        typeColor = Colors.orange;
        typeIcon = Icons.search;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.help;
    }

    return Card(
      color: const Color(0xFF313334),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor,
          child: Icon(typeIcon, color: Colors.white, size: 20),
        ),
        title: Text(
          '$collection/$document',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${type.toUpperCase()} - $count opérations',
              style: TextStyle(color: typeColor),
            ),
            if (details != null)
              Text(
                details,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
        trailing: Text(
          time,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

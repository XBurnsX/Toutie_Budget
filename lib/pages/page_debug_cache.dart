import 'package:flutter/material.dart';
import '../services/cache_service.dart';
import '../services/persistent_cache_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PageDebugCache extends StatefulWidget {
  const PageDebugCache({super.key});

  @override
  State<PageDebugCache> createState() => _PageDebugCacheState();
}

class _PageDebugCacheState extends State<PageDebugCache> {
  Map<String, dynamic> _cacheStats = {};
  Map<String, int> _persistentCacheSize = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    setState(() => _isLoading = true);

    try {
      _cacheStats = CacheService.getCacheStats();

      if (!kIsWeb) {
        _persistentCacheSize = await PersistentCacheService.getCacheSize();
      }
    } catch (e) {
      // Ignorer les erreurs
    }

    setState(() => _isLoading = false);
  }

  Future<void> _clearAllCache() async {
    try {
      CacheService.invalidateAll();

      if (!kIsWeb) {
        await PersistentCacheService.clearAllCache();
      }

      await _loadCacheStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache vidé avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du vidage du cache: $e')),
        );
      }
    }
  }

  Future<void> _cleanExpiredCache() async {
    try {
      if (!kIsWeb) {
        await PersistentCacheService.cleanExpiredCache();
      }

      await _loadCacheStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache expiré nettoyé avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du nettoyage: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Cache'),
        backgroundColor: const Color(0xFF18191A),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: const Color(0xFF18191A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCacheStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCacheStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCacheInfoCard(),
                    const SizedBox(height: 16),
                    _buildPersistentCacheCard(),
                    const SizedBox(height: 16),
                    _buildActionsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCacheInfoCard() {
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
                  Icons.memory,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Cache Mémoire',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Plateforme', kIsWeb ? 'Web' : 'Mobile'),
            _buildInfoRow(
                'Durée cache', '${_cacheStats['cacheDuration'] ?? 0} minutes'),
            _buildInfoRow('Comptes en cache',
                _cacheStats['comptesCached'] == true ? 'Oui' : 'Non'),
            _buildInfoRow('Catégories en cache',
                _cacheStats['categoriesCached'] == true ? 'Oui' : 'Non'),
            _buildInfoRow('Comptes avec transactions',
                '${_cacheStats['transactionsCached'] ?? 0}'),
            if (_cacheStats['lastComptesUpdate'] != null)
              _buildInfoRow('Dernière MAJ comptes',
                  _formatDateTime(_cacheStats['lastComptesUpdate'])),
            if (_cacheStats['lastCategoriesUpdate'] != null)
              _buildInfoRow('Dernière MAJ catégories',
                  _formatDateTime(_cacheStats['lastCategoriesUpdate'])),
            if (_cacheStats['lastWebSync'] != null)
              _buildInfoRow('Dernière sync web',
                  _formatDateTime(_cacheStats['lastWebSync'])),
            _buildInfoRow('Sync en cours',
                _cacheStats['isWebSyncInProgress'] == true ? 'Oui' : 'Non'),
          ],
        ),
      ),
    );
  }

  Widget _buildPersistentCacheCard() {
    if (kIsWeb) {
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
                    Icons.storage,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Cache Persistant',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Non disponible sur le web',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

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
                  Icons.storage,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Cache Persistant (SQLite)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                'Comptes stockés', '${_persistentCacheSize['comptes'] ?? 0}'),
            _buildInfoRow('Catégories stockées',
                '${_persistentCacheSize['categories'] ?? 0}'),
            _buildInfoRow('Comptes avec transactions',
                '${_persistentCacheSize['transactions'] ?? 0}'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
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
                  Icons.settings,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _clearAllCache,
                icon: const Icon(Icons.clear_all),
                label: const Text('Vider tout le cache'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cleanExpiredCache,
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('Nettoyer cache expiré'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Format invalide';
    }
  }
}

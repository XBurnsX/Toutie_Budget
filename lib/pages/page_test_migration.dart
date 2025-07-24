import 'package:flutter/material.dart';
import '../services/data_service_config.dart';
import '../services/interfaces/data_service_interface.dart';

class PageTestMigration extends StatefulWidget {
  const PageTestMigration({super.key});

  @override
  State<PageTestMigration> createState() => _PageTestMigrationState();
}

class _PageTestMigrationState extends State<PageTestMigration> {
  bool _isLoading = false;
  String _status = 'Prêt';
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    // Basculer automatiquement vers PocketBase pour les tests
    DataServiceConfig.usePocketBase();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  Future<void> _testFirebase() async {
    setState(() {
      _isLoading = true;
      _status = 'Test Firebase...';
      _logs.clear();
    });

    try {
      _addLog('🔄 Basculement vers Firebase...');
      DataServiceConfig.useFirebase();

      _addLog('🔍 Test lecture des comptes...');
      final dataService = DataServiceConfig.instance;
      final comptes = await dataService.lireComptes();
      _addLog('✅ ${comptes.length} comptes lus depuis Firebase');

      _addLog('🔍 Test lecture des catégories...');
      final categories = await dataService.lireCategories();
      _addLog('✅ ${categories.length} catégories lues depuis Firebase');

      _addLog('🔍 Test lecture des tiers...');
      final tiers = await dataService.lireTiers();
      _addLog('✅ ${tiers.length} tiers lus depuis Firebase');

      setState(() {
        _status = 'Test Firebase réussi !';
      });
    } catch (e) {
      _addLog('❌ Erreur test Firebase: $e');
      setState(() {
        _status = 'Erreur Firebase: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testPocketBase() async {
    setState(() {
      _isLoading = true;
      _status = 'Test PocketBase...';
      _logs.clear();
    });

    try {
      _addLog('🔄 Basculement vers PocketBase...');
      DataServiceConfig.usePocketBase();

      _addLog('🔍 Test lecture des comptes...');
      final dataService = DataServiceConfig.instance;
      final comptes = await dataService.lireComptes();
      _addLog('✅ ${comptes.length} comptes lus depuis PocketBase');

      _addLog('🔍 Test lecture des catégories...');
      final categories = await dataService.lireCategories();
      _addLog('✅ ${categories.length} catégories lues depuis PocketBase');

      _addLog('🔍 Test lecture des tiers...');
      final tiers = await dataService.lireTiers();
      _addLog('✅ ${tiers.length} tiers lus depuis PocketBase');

      if (comptes.isNotEmpty) {
        _addLog('🔍 Test lecture des transactions du premier compte...');
        final transactions =
            await dataService.lireTransactionsCompte(comptes.first.id);
        _addLog('✅ ${transactions.length} transactions lues depuis PocketBase');
      }

      _addLog('🔍 Test lecture des dettes actives...');
      final dettes = await dataService.lireDettesActives();
      _addLog('✅ ${dettes.length} dettes actives lues depuis PocketBase');

      if (categories.isNotEmpty) {
        _addLog('🔍 Test lecture des enveloppes de la première catégorie...');
        final enveloppes =
            await dataService.lireEnveloppesCategorie(categories.first.id);
        _addLog('✅ ${enveloppes.length} enveloppes lues depuis PocketBase');
      }

      setState(() {
        _status = 'Test PocketBase réussi !';
      });
    } catch (e) {
      _addLog('❌ Erreur test PocketBase: $e');
      setState(() {
        _status = 'Erreur PocketBase: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testEcriturePocketBase() async {
    setState(() {
      _isLoading = true;
      _status = 'Test Écriture PocketBase...';
      _logs.clear();
    });

    try {
      _addLog('🔄 Basculement vers PocketBase...');
      DataServiceConfig.usePocketBase();

      final dataService = DataServiceConfig.instance;

      _addLog('🔍 Test ajout d\'un tiers...');
      await dataService
          .ajouterTiers('Test Tiers ${DateTime.now().millisecondsSinceEpoch}');
      _addLog('✅ Tiers ajouté avec succès');

      _addLog('🔍 Test lecture des tiers après ajout...');
      final tiers = await dataService.lireTiers();
      _addLog('✅ ${tiers.length} tiers lus après ajout');

      setState(() {
        _status = 'Test Écriture PocketBase réussi !';
      });
    } catch (e) {
      _addLog('❌ Erreur test écriture PocketBase: $e');
      setState(() {
        _status = 'Erreur Écriture PocketBase: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Migration'),
        backgroundColor: const Color(0xFF18191A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Card(
              color: const Color(0xFF232526),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Backend actuel: ${DataServiceConfig.isUsingPocketBase ? "PocketBase" : "Firebase"}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Boutons de test
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _testFirebase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Test Firebase',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _testPocketBase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Test PocketBase',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Test d'écriture
            ElevatedButton(
              onPressed: _isLoading ? null : _testEcriturePocketBase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Test Écriture PocketBase',
                style: TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(height: 16),

            // Logs
            Expanded(
              child: Card(
                color: const Color(0xFF232526),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Logs:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                log,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

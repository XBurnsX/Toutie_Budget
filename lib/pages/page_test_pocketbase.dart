import 'package:flutter/material.dart';
import '../services/migration_service.dart';
import '../services/pocketbase_service.dart';
import '../services/auth_service.dart';
import '../pocketbase_config.dart';

class PageTestPocketBase extends StatefulWidget {
  const PageTestPocketBase({super.key});

  @override
  State<PageTestPocketBase> createState() => _PageTestPocketBaseState();
}

class _PageTestPocketBaseState extends State<PageTestPocketBase> {
  final MigrationService _migrationService = MigrationService();
  final PocketBaseService _pocketBaseService = PocketBaseService();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String _statusMessage = '';
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _initializePocketBase();
  }

  Future<void> _initializePocketBase() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initialisation de PocketBase...';
    });

    try {
      await _authService.initialize();
      _addLog('✅ PocketBase initialisé avec succès');
      setState(() {
        _statusMessage = 'PocketBase initialisé';
        _isLoading = false;
      });
    } catch (e) {
      _addLog('❌ Erreur d\'initialisation PocketBase: $e');
      setState(() {
        _statusMessage = 'Erreur d\'initialisation';
        _isLoading = false;
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  Future<void> _testPocketBaseConnection() async {
    try {
      final results = await _migrationService.testConnections();
      final isConnected = results['pocketbase'] ?? false;

      if (isConnected) {
        _addLog('✅ Connexion PocketBase réussie');
      } else {
        _addLog('❌ Échec de connexion PocketBase');
      }
    } catch (e) {
      _addLog('❌ Erreur test PocketBase: $e');
    }
  }

  Future<void> _testFirebaseConnection() async {
    try {
      final results = await _migrationService.testConnections();
      final isConnected = results['firebase'] ?? false;

      if (isConnected) {
        _addLog('✅ Connexion Firebase réussie');
      } else {
        _addLog('❌ Échec de connexion Firebase');
      }
    } catch (e) {
      _addLog('❌ Erreur test Firebase: $e');
    }
  }

  Future<void> _compareData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Comparaison des données...';
    });

    try {
      await _migrationService.compareData();
      _addLog('✅ Comparaison terminée');
      setState(() {
        _statusMessage = 'Comparaison terminée';
      });
    } catch (e) {
      _addLog('❌ Erreur lors de la comparaison: $e');
      setState(() {
        _statusMessage = 'Erreur de comparaison';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _migrateTestData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Migration des données de test...';
    });

    try {
      await _migrationService.migrateTestData();
      _addLog('✅ Migration de test terminée');
      setState(() {
        _statusMessage = 'Migration de test terminée';
      });
    } catch (e) {
      _addLog('❌ Erreur lors de la migration: $e');
      setState(() {
        _statusMessage = 'Erreur de migration';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Authentification Google...';
    });

    try {
      final success = await _authService.signInWithGoogle();
      if (success) {
        _addLog('✅ Authentification Google réussie');
        setState(() {
          _statusMessage = 'Authentification Google réussie';
        });
      } else {
        _addLog('❌ Échec authentification Google');
        setState(() {
          _statusMessage = 'Échec authentification Google';
        });
      }
    } catch (e) {
      _addLog('❌ Erreur authentification Google: $e');
      setState(() {
        _statusMessage = 'Erreur authentification Google';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncAuthentication() async {
    try {
      final authService = AuthService();
      await authService.signInWithGoogle();
      _addLog('✅ Authentification synchronisée');
    } catch (e) {
      _addLog('❌ Erreur synchronisation: $e');
    }
  }

  void _generateReport() {
    _migrationService.generateMigrationReport();
    _addLog('📋 Rapport de migration généré');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test PocketBase'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Status: $_statusMessage',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Boutons de test
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTestButton(
                      'Test Connexion PocketBase',
                      _testPocketBaseConnection,
                      Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildTestButton(
                      'Test Connexion Firebase',
                      _testFirebaseConnection,
                      Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    _buildTestButton(
                      'Comparer les Données',
                      _compareData,
                      Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    _buildTestButton(
                      'Auth Google',
                      _signInWithGoogle,
                      Colors.red,
                    ),
                    const SizedBox(height: 8),
                    _buildTestButton(
                      'Synchroniser Auth',
                      _syncAuthentication,
                      Colors.teal,
                    ),
                    const SizedBox(height: 8),
                    _buildTestButton(
                      'Migration de Test',
                      _migrateTestData,
                      Colors.purple,
                    ),
                    const SizedBox(height: 8),
                    _buildTestButton(
                      'Générer Rapport',
                      _generateReport,
                      Colors.indigo,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Logs
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Logs:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 2.0,
                            ),
                            child: Text(
                              _logs[index],
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(String text, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(text),
      ),
    );
  }
}

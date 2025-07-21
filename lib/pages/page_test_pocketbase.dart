// 📁 Chemin : lib/pages/page_test_pocketbase.dart
// 🔗 Dépendances : migration_service.dart, auth_service.dart
// 📋 Description : Page de test et migration PocketBase simplifiée

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/migration_service.dart';
import '../services/auth_service.dart';

class PageTestPocketBase extends StatefulWidget {
  const PageTestPocketBase({super.key});

  @override
  State<PageTestPocketBase> createState() => _PageTestPocketBaseState();
}

class _PageTestPocketBaseState extends State<PageTestPocketBase> {
  final MigrationService _migrationService = MigrationService();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String _statusMessage = 'Prêt';
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _verifierStatutConnexion();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
    print(message); // Afficher aussi dans la console
  }

  Future<void> _verifierStatutConnexion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _addLog('✅ Utilisateur connecté: ${user.email}');
      setState(() {
        _statusMessage = 'Utilisateur connecté: ${user.email}';
      });
    } else {
      _addLog('⚠️ Aucun utilisateur connecté');
      setState(() {
        _statusMessage = 'Aucun utilisateur connecté';
      });
    }
  }

  Future<void> _testerConnexions() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Test des connexions...';
    });

    try {
      _addLog('🔄 Test des connexions...');
      final results = await _migrationService.testConnections();
      
      if (results['firebase'] == true) {
        _addLog('✅ Connexion Firebase OK');
      } else {
        _addLog('❌ Connexion Firebase échouée');
      }

      if (results['pocketbase'] == true) {
        _addLog('✅ Connexion PocketBase OK');
      } else {
        _addLog('❌ Connexion PocketBase échouée');
      }

      setState(() {
        _statusMessage = 'Tests de connexion terminés';
      });
    } catch (e) {
      _addLog('❌ Erreur test connexions: $e');
      setState(() {
        _statusMessage = 'Erreur lors des tests';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _connexionGoogle() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connexion Google...';
    });

    try {
      _addLog('🔄 Connexion avec Google...');
      final success = await _authService.signInWithGoogle();
      
      if (success) {
        final user = FirebaseAuth.instance.currentUser;
        _addLog('✅ Connexion Google réussie: ${user?.email}');
        setState(() {
          _statusMessage = 'Connecté: ${user?.email}';
        });
      } else {
        _addLog('❌ Connexion Google échouée');
        setState(() {
          _statusMessage = 'Échec connexion Google';
        });
      }
    } catch (e) {
      _addLog('❌ Erreur connexion Google: $e');
      setState(() {
        _statusMessage = 'Erreur connexion Google';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _migrerDonnees() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _addLog('❌ Vous devez être connecté pour migrer');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Migration en cours...';
    });

    try {
      _addLog('🚀 Début de la migration pour ${user.email}...');
      await _migrationService.migrateCurrentUserData();
      _addLog('✅ Migration terminée avec succès !');
      
      setState(() {
        _statusMessage = 'Migration terminée';
      });
    } catch (e) {
      _addLog('❌ Erreur migration: $e');
      setState(() {
        _statusMessage = 'Erreur migration';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _comparerDonnees() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Comparaison des données...';
    });

    try {
      _addLog('📊 Comparaison des données...');
      await _migrationService.compareData();
      _addLog('✅ Comparaison terminée');
      
      setState(() {
        _statusMessage = 'Comparaison terminée';
      });
    } catch (e) {
      _addLog('❌ Erreur comparaison: $e');
      setState(() {
        _statusMessage = 'Erreur comparaison';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifierCollections() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Vérification collections...';
    });

    try {
      _addLog('🔍 Vérification des collections PocketBase...');
      await _migrationService.verifyAllPocketBaseCollections();
      _addLog('✅ Vérification terminée');
      
      setState(() {
        _statusMessage = 'Vérification terminée';
      });
    } catch (e) {
      _addLog('❌ Erreur vérification: $e');
      setState(() {
        _statusMessage = 'Erreur vérification';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _genererRapport() async {
    try {
      _addLog('📋 Génération du rapport...');
      final rapport = await _migrationService.generateMigrationReport();
      _addLog('📄 Rapport généré:');
      
      // Afficher les premières lignes du rapport dans les logs
      final lignes = rapport.split('\n').take(5).toList();
      for (final ligne in lignes) {
        if (ligne.isNotEmpty) {
          _addLog('   $ligne');
        }
      }
      _addLog('📄 Voir console pour rapport complet');
      print('\n' + rapport); // Afficher le rapport complet dans la console
      
    } catch (e) {
      _addLog('❌ Erreur génération rapport: $e');
    }
  }

  void _viderLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migration PocketBase'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _viderLogs,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Vider les logs',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Statut
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 8),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Boutons principaux
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Section Préparation
                    _buildSectionHeader('🔧 Préparation'),
                    _buildActionButton(
                      '🔍 Tester Connexions',
                      'Vérifier Firebase + PocketBase',
                      _testerConnexions,
                      Colors.blue,
                    ),
                    _buildActionButton(
                      '👤 Connexion Google',
                      'Se connecter avec Google',
                      _connexionGoogle,
                      Colors.red,
                    ),

                    const SizedBox(height: 16),

                    // Section Migration
                    _buildSectionHeader('🚀 Migration'),
                    _buildActionButton(
                      '📦 Migrer Mes Données',
                      'Migrer données de l\'utilisateur connecté',
                      _migrerDonnees,
                      Colors.green,
                    ),
                    _buildActionButton(
                      '📊 Comparer Données',
                      'Comparer Firebase vs PocketBase',
                      _comparerDonnees,
                      Colors.orange,
                    ),

                    const SizedBox(height: 16),

                    // Section Vérification
                    _buildSectionHeader('🔎 Vérification'),
                    _buildActionButton(
                      '🗄️ Vérifier Collections',
                      'Vérifier les collections PocketBase',
                      _verifierCollections,
                      Colors.purple,
                    ),
                    _buildActionButton(
                      '📋 Générer Rapport',
                      'Générer rapport de migration',
                      _genererRapport,
                      Colors.teal,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Logs
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '📜 Logs',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_logs.length} entrées',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[50],
                          ),
                          child: _logs.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Aucun log pour le moment',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _logs.length,
                                  itemBuilder: (context, index) {
                                    final log = _logs[index];
                                    Color textColor = Colors.black87;
                                    
                                    // Coloration selon le type de message
                                    if (log.contains('✅')) {
                                      textColor = Colors.green[700]!;
                                    } else if (log.contains('❌')) {
                                      textColor = Colors.red[700]!;
                                    } else if (log.contains('⚠️')) {
                                      textColor = Colors.orange[700]!;
                                    } else if (log.contains('🔄')) {
                                      textColor = Colors.blue[700]!;
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 2.0,
                                      ),
                                      child: Text(
                                        log,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textColor,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    );
                                  },
                                ),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    VoidCallback onPressed,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/*// 📁 Chemin : lib/pages/page_test_auth_pocketbase.dart
// 🔗 Dépendances : auth_service.dart
// 📋 Description : Page de test pour l'authentification PocketBase

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:pocketbase/pocketbase.dart';

class PageTestAuthPocketBase extends StatefulWidget {
  const PageTestAuthPocketBase({super.key});

  @override
  State<PageTestAuthPocketBase> createState() => _PageTestAuthPocketBaseState();
}

class _PageTestAuthPocketBaseState extends State<PageTestAuthPocketBase> {
  bool _isLoading = false;
  String _statusMessage = '';
  RecordModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  void _checkCurrentUser() {
    setState(() {
      _currentUser = AuthService.currentUser;
      _statusMessage = _currentUser != null
          ? '✅ Utilisateur connecté: ${_currentUser!.data['email']}'
          : '❌ Aucun utilisateur connecté';
    });
  }

  Future<void> _testSignIn() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '🔄 Tentative de connexion Google...';
    });

    try {
      final user = await AuthService.signInWithGoogle();

      setState(() {
        _isLoading = false;
        if (user != null) {
          _currentUser = user;
          _statusMessage =
              '✅ Connexion réussie!\nEmail: ${user.data['email']}\nNom: ${user.data['name']}';
        } else {
          _statusMessage = '❌ Connexion annulée par l\'utilisateur';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Erreur de connexion: $e';
      });
    }
  }

  Future<void> _testSignOut() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '🔄 Déconnexion...';
    });

    try {
      await AuthService.signOut();

      setState(() {
        _isLoading = false;
        _currentUser = null;
        _statusMessage = '✅ Déconnexion réussie';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Erreur de déconnexion: $e';
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '🔍 Test de connexion PocketBase...';
    });

    try {
      // Test de connexion basique
      final response = await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _isLoading = false;
        _statusMessage = '✅ Connexion PocketBase testée (simulation)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Erreur de connexion: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Auth PocketBase'),
        backgroundColor: const Color(0xFF18191A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Statut actuel
            Card(
              color: const Color(0xFF232526),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 Statut actuel:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (_currentUser != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        '👤 Informations utilisateur:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ID: ${_currentUser!.id}\n'
                        'Email: ${_currentUser!.data['email']}\n'
                        'Nom: ${_currentUser!.data['name']}\n'
                        'Connecté: ${AuthService.isSignedIn ? "Oui" : "Non"}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Boutons de test
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              ElevatedButton.icon(
                onPressed: _testConnection,
                icon: const Icon(Icons.wifi),
                label: const Text('Test Connexion PocketBase'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _testSignIn,
                icon: const Icon(Icons.login),
                label: const Text('Connexion Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 8),
              if (_currentUser != null)
                ElevatedButton.icon(
                  onPressed: _testSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Déconnexion'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
            ],

            const Spacer(),

            // Informations de debug
            Card(
              color: const Color(0xFF1A1A1A),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔧 Informations de debug:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AuthService.isSignedIn: ${AuthService.isSignedIn}\n'
                      'AuthService.currentUserId: ${AuthService.currentUserId}\n'
                      'AuthService.currentUserEmail: ${AuthService.currentUserEmail}\n'
                      'AuthService.currentUserName: ${AuthService.currentUserName}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
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
}
*/
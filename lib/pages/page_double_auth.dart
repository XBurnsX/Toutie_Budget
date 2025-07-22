/*// 📁 Chemin : lib/pages/page_double_auth.dart
// 🔗 Dépendances : auth_service.dart, auth_service_firebase.dart
// 📋 Description : Page de double authentification (Firebase + PocketBase)

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/auth_service_firebase.dart';

class PageDoubleAuth extends StatefulWidget {
  const PageDoubleAuth({super.key});

  @override
  State<PageDoubleAuth> createState() => _PageDoubleAuthState();
}

class _PageDoubleAuthState extends State<PageDoubleAuth> {
  bool _isLoading = false;
  String _statusMessage = '';
  String? _currentAuthType;

  @override
  void initState() {
    super.initState();
    _checkCurrentAuth();
  }

  void _checkCurrentAuth() {
    // Vérifier si connecté à PocketBase
    if (AuthService.isSignedIn) {
      setState(() {
        _currentAuthType = 'PocketBase';
        _statusMessage =
            '✅ Connecté à PocketBase: ${AuthService.currentUserEmail}';
      });
    }
    // Vérifier si connecté à Firebase
    else if (AuthServiceFirebase.isSignedIn) {
      setState(() {
        _currentAuthType = 'Firebase';
        _statusMessage =
            '✅ Connecté à Firebase: ${AuthServiceFirebase.currentUserEmail}';
      });
    } else {
      setState(() {
        _currentAuthType = null;
        _statusMessage = '❌ Aucune connexion active';
      });
    }
  }

  Future<void> _connexionPocketBase() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '🔄 Connexion PocketBase...';
    });

    try {
      final user = await AuthService.signInWithGoogle();

      setState(() {
        _isLoading = false;
        if (user != null) {
          _currentAuthType = 'PocketBase';
          _statusMessage =
              '✅ Connexion PocketBase réussie!\nEmail: ${user.data['email']}';
        } else {
          _statusMessage = '❌ Connexion PocketBase annulée';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Erreur connexion PocketBase: $e';
      });
    }
  }

  Future<void> _connexionFirebase() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '🔄 Connexion Firebase...';
    });

    try {
      final userCredential = await AuthServiceFirebase.signInWithGoogle();

      setState(() {
        _isLoading = false;
        if (userCredential != null) {
          _currentAuthType = 'Firebase';
          _statusMessage =
              '✅ Connexion Firebase réussie!\nEmail: ${userCredential.user?.email}';
        } else {
          _statusMessage = '❌ Connexion Firebase annulée';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Erreur connexion Firebase: $e';
      });
    }
  }

  Future<void> _deconnexion() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '🔄 Déconnexion...';
    });

    try {
      if (_currentAuthType == 'PocketBase') {
        await AuthService.signOut();
      } else if (_currentAuthType == 'Firebase') {
        await AuthServiceFirebase.signOut();
      }

      setState(() {
        _isLoading = false;
        _currentAuthType = null;
        _statusMessage = '✅ Déconnexion réussie';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Erreur déconnexion: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Double Authentification'),
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
                    if (_currentAuthType != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _currentAuthType == 'PocketBase'
                              ? Colors.green.withOpacity(0.2)
                              : Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🔐 Connecté à: $_currentAuthType',
                          style: TextStyle(
                            color: _currentAuthType == 'PocketBase'
                                ? Colors.green
                                : Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Boutons de connexion
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              ElevatedButton.icon(
                onPressed: _connexionPocketBase,
                icon: const Icon(Icons.cloud),
                label: const Text('Connexion PocketBase'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _connexionFirebase,
                icon: const Icon(Icons.local_fire_department),
                label: const Text('Connexion Firebase'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 8),
              if (_currentAuthType != null)
                ElevatedButton.icon(
                  onPressed: _deconnexion,
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
                      'PocketBase.isSignedIn: ${AuthService.isSignedIn}\n'
                      'Firebase.isSignedIn: ${AuthServiceFirebase.isSignedIn}\n'
                      'PocketBase.email: ${AuthService.currentUserEmail}\n'
                      'Firebase.email: ${AuthServiceFirebase.currentUserEmail}',
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
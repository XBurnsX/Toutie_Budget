import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:toutie_budget/services/firebase_service.dart';
import 'package:toutie_budget/services/theme_service.dart';

import 'package:provider/provider.dart';
import 'page_archivage.dart';
import 'page_import_csv.dart';
import 'page_debug_cache.dart';
import 'page_firebase_monitor.dart';

import '../themes/dropdown_theme_extension.dart';

class PageParametres extends StatefulWidget {
  const PageParametres({super.key});

  @override
  State<PageParametres> createState() => _PageParametresState();
}

class _PageParametresState extends State<PageParametres> {
  bool notifications = true;
  String langue = 'fr';
  double budgetNotif = 80;
  int _aboutClickCount = 0;
  DateTime? _lastAboutClick;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Paramètres'),
          elevation: 0,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _buildParametresContent(context),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        elevation: 0,
      ),
      body: _buildParametresContent(context),
    );
  }

  Widget _buildParametresContent(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return ListView(
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              subtitle: const Text('Recevoir des notifications importantes'),
              trailing: Switch(
                value: notifications,
                onChanged: (val) => setState(() => notifications = val),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archive'),
              subtitle: const Text(
                'Voir et restaurer les comptes ou enveloppes archivés',
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PageArchivage(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Langue'),
              subtitle: Text(langue == 'fr' ? 'Français' : 'Anglais'),
              trailing: DropdownButton<String>(
                value: langue,
                dropdownColor: Theme.of(context).dropdownColor,
                items: const [
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'en', child: Text('Anglais')),
                ],
                onChanged: (val) => setState(() => langue = val ?? 'fr'),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.palette, color: themeService.primaryColor),
              title: const Text('Thème'),
              subtitle: Text('Couleur principale de l\'application'),
              trailing: SizedBox(
                width: 150,
                child: DropdownButton<String>(
                  value: themeService.currentTheme,
                  isExpanded: true,
                  underline: Container(),
                  dropdownColor: Theme.of(context).dropdownColor,
                  items: ThemeService.themeNames.entries.map((entry) {
                    final themeName = entry.key;
                    final displayName = entry.value;
                    final themeColor = ThemeService.themeColors[themeName]!;

                    return DropdownMenuItem<String>(
                      value: themeName,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: themeColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) async {
                    if (newValue != null) {
                      await themeService.setTheme(newValue);

                      // Afficher un message de confirmation
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Thème ${ThemeService.themeNames[newValue]} appliqué !',
                            ),
                            backgroundColor: ThemeService.themeColors[newValue],
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Importer des transactions'),
              subtitle: const Text(
                'Importer des transactions depuis un fichier CSV',
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PageImportCsv(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Réinitialiser votre compte'),
              subtitle: const Text(
                'Supprimer toutes vos données de la base de données',
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirmer la réinitialisation'),
                    content: const Text(
                      'Toutes vos données (comptes, enveloppes, transactions, etc.) seront supprimées. Êtes-vous sûr ?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Oui, réinitialiser'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _deleteAllUserData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Toutes vos données ont été supprimées.'),
                    ),
                  );
                  await FirebaseService().signOut();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.memory),
              title: const Text('Debug Cache'),
              subtitle: const Text(
                'Gérer et surveiller le cache de l\'application',
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PageDebugCache(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('À propos'),
              subtitle: const Text('Toutie Budget'),
              onTap: _handleAboutTap,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.black),
              title: const Text('Déconnexion'),
              onTap: () async {
                await FirebaseService().signOut();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            const Divider(),
          ],
        );
      },
    );
  }

  void _handleAboutTap() {
    final now = DateTime.now();

    // Réinitialiser le compteur si plus de 3 secondes se sont écoulées
    if (_lastAboutClick != null &&
        now.difference(_lastAboutClick!).inSeconds > 3) {
      _aboutClickCount = 0;
    }

    _aboutClickCount++;
    _lastAboutClick = now;

    // Si 5 clics ont été effectués, ouvrir le monitoring Firebase
    if (_aboutClickCount >= 5) {
      _aboutClickCount = 0; // Réinitialiser le compteur
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const PageFirebaseMonitor(),
        ),
      );
    }
  }

  Future<void> _deleteAllUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firebaseService = FirebaseService();

    // Supprimer tous les prêts personnels (dettes) de l'utilisateur
    final dettesQuery = await FirebaseFirestore.instance
        .collection('dettes')
        .where('userId', isEqualTo: user.uid)
        .get();

    // Collecter les IDs des dettes pour supprimer les comptes associés
    final List<String> detteIds = [];
    for (final doc in dettesQuery.docs) {
      detteIds.add(doc.id);
      await doc.reference.delete();
    }

    // Supprimer les comptes de dette associés aux dettes supprimées
    if (detteIds.isNotEmpty) {
      final comptesDetteQuery = await FirebaseFirestore.instance
          .collection('comptes')
          .where('userId', isEqualTo: user.uid)
          .where('detteAssocieeId', whereIn: detteIds)
          .get();

      for (final doc in comptesDetteQuery.docs) {
        await doc.reference.delete();
      }
    }

    // Supprimer les autres comptes (non-dette)
    final comptes = await firebaseService.lireComptes().first;
    for (final compte in comptes) {
      await firebaseService.supprimerDocument('comptes', compte.id);
    }

    // Supprimer les catégories
    final categories = await firebaseService.lireCategories().first;
    for (final categorie in categories) {
      await firebaseService.supprimerDocument('categories', categorie.id);
    }

    // Supprimer toutes les transactions de l'utilisateur
    final transactionsQuery = await FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: user.uid)
        .get();

    for (final doc in transactionsQuery.docs) {
      await doc.reference.delete();
    }

    // Supprimer tous les tiers de l'utilisateur
    final tiersQuery = await FirebaseFirestore.instance
        .collection('tiers')
        .where('userId', isEqualTo: user.uid)
        .get();

    for (final doc in tiersQuery.docs) {
      await doc.reference.delete();
    }

    // Supprimer les paramètres utilisateur s'ils existent
    final userSettingsQuery = await FirebaseFirestore.instance
        .collection('user_settings')
        .where('userId', isEqualTo: user.uid)
        .get();

    for (final doc in userSettingsQuery.docs) {
      await doc.reference.delete();
    }
  }
}

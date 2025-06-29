import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:toutie_budget/services/firebase_service.dart';
import 'page_archivage.dart';

class PageParametres extends StatefulWidget {
  const PageParametres({super.key});

  @override
  State<PageParametres> createState() => _PageParametresState();
}

class _PageParametresState extends State<PageParametres> {
  bool notifications = true;
  String langue = 'fr';
  double budgetNotif = 80;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
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
                MaterialPageRoute(builder: (context) => const PageArchivage()),
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
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'en', child: Text('Anglais')),
              ],
              onChanged: (val) => setState(() => langue = val ?? 'fr'),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.warning),
            title: const Text('Alerte budget'),
            subtitle: Text(
              'Alerte si le budget dépasse ${budgetNotif.toInt()}%',
            ),
            trailing: SizedBox(
              width: 120,
              child: Slider(
                value: budgetNotif,
                min: 50,
                max: 100,
                divisions: 10,
                label: '${budgetNotif.toInt()}%',
                onChanged: (val) => setState(() => budgetNotif = val),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.update, color: Colors.blue),
            title: const Text(
              'Mise à jour',
              style: TextStyle(color: Colors.blue),
            ),
            onTap: () async {
              final info = await PackageInfo.fromPlatform();
              final currentVersion = info.version;
              final remoteConfig = FirebaseRemoteConfig.instance;
              await remoteConfig.setConfigSettings(
                RemoteConfigSettings(
                  fetchTimeout: const Duration(seconds: 10),
                  minimumFetchInterval: const Duration(seconds: 0),
                ),
              );
              await remoteConfig.fetchAndActivate();
              final latestVersion = remoteConfig.getString('latest_version');
              final apkUrl = remoteConfig.getString('apk_url');
              if (latestVersion.isNotEmpty &&
                  apkUrl.isNotEmpty &&
                  latestVersion.compareTo(currentVersion) > 0) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Mise à jour disponible'),
                    content: Text(
                      'Vous avez la version $currentVersion. La version $latestVersion est disponible.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();

                          // Afficher un dialogue de progression
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return StatefulBuilder(
                                builder: (context, setState) {
                                  double progress = 0.0;
                                  String statusMessage =
                                      'Préparation du téléchargement...';

                                  return AlertDialog(
                                    title: const Text(
                                      'Téléchargement en cours',
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        LinearProgressIndicator(
                                          value: progress,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(statusMessage),
                                        Text(
                                          '${(progress * 100).toStringAsFixed(0)}%',
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );

                          try {
                            final tempDir = await getTemporaryDirectory();
                            final savePath = "${tempDir.path}/mise_a_jour.apk";
                            final dio = Dio();

                            // Télécharger avec indicateur de progression
                            await dio.download(
                              apkUrl,
                              savePath,
                              onReceiveProgress: (received, total) {
                                if (total != -1) {
                                  final progress = received / total;
                                  // Mettre à jour la progression (nécessiterait un StatefulWidget pour être parfait)
                                  print(
                                    'Progression: ${(progress * 100).toStringAsFixed(1)}%',
                                  );
                                }
                              },
                            );

                            // Fermer le dialogue de progression
                            Navigator.of(context).pop();

                            // Afficher message de succès avec instructions
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Téléchargement terminé ! Ouverture de l\'installateur...',
                                ),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 3),
                              ),
                            );

                            // Ouvrir le fichier APK pour installation
                            final result = await OpenFile.open(savePath);

                            // Analyser le résultat et donner des instructions à l'utilisateur
                            if (result.type == ResultType.done) {
                              // Installation lancée avec succès
                              _showInstallationInstructions();
                            } else if (result.type == ResultType.noAppToOpen) {
                              _showInstallationError(
                                'Aucune application trouvée pour installer le fichier APK. Vérifiez que l\'installation depuis des sources inconnues est autorisée.',
                              );
                            } else if (result.type ==
                                ResultType.permissionDenied) {
                              _showInstallationError(
                                'Permission refusée. Allez dans Paramètres > Sécurité > Sources inconnues et autorisez l\'installation d\'applications.',
                              );
                            } else {
                              _showInstallationError(
                                'Erreur lors de l\'ouverture: ${result.message ?? "Erreur inconnue"}',
                              );
                            }
                          } catch (e) {
                            // Fermer le dialogue de progression s'il est encore ouvert
                            Navigator.of(context).pop();

                            String errorMessage = 'Erreur inconnue';
                            if (e.toString().contains('SocketException')) {
                              errorMessage = 'Erreur de connexion internet';
                            } else if (e.toString().contains('HttpException')) {
                              errorMessage =
                                  'Erreur lors du téléchargement (serveur)';
                            } else if (e.toString().contains(
                              'PathAccessException',
                            )) {
                              errorMessage = 'Erreur d\'accès au stockage';
                            } else {
                              errorMessage = 'Erreur : ${e.toString()}';
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMessage),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        },
                        child: const Text('Télécharger'),
                      ),
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Vous avez la version $currentVersion. Aucune mise à jour disponible.',
                    ),
                  ),
                );
              }
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
            leading: const Icon(Icons.info_outline),
            title: const Text('À propos'),
            subtitle: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data?.version ?? '';
                return Text('Toutie Budget v$version');
              },
            ),
            onTap: () async {
              final info = await PackageInfo.fromPlatform();
              showAboutDialog(
                context: context,
                applicationName: 'Toutie Budget',
                applicationVersion: info.version,
                applicationLegalese: '© 2025 XBurnsX Inc',
              );
            },
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
      ),
    );
  }

  void _showInstallationInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Installation en cours'),
        content: const Text(
          'L\'installateur a été ouvert. Suivez les instructions à l\'écran pour terminer l\'installation de la mise à jour.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showInstallationError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur d\'installation'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

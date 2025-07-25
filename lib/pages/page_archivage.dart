import 'package:flutter/material.dart';
import 'package:toutie_budget/services/firebase_service.dart';
import '../models/compte.dart';
import '../models/categorie.dart';

class PageArchivage extends StatefulWidget {
  const PageArchivage({super.key});

  @override
  State<PageArchivage> createState() => _PageArchivageState();
}

class _PageArchivageState extends State<PageArchivage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivage'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Compte'),
            Tab(text: 'Enveloppe'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Onglet Comptes archivés
          _buildComptesArchives(),
          // Onglet Enveloppes archivées
          _buildEnveloppesArchives(),
        ],
      ),
    );
  }

  Widget _buildComptesArchives() {
    return StreamBuilder<List<Compte>>(
      stream: FirebaseService().lireComptes(),
      builder: (context, snapshot) {
        final archives =
            (snapshot.data ?? []).where((c) => c.estArchive == true).toList();
        if (archives.isEmpty) {
          return const Center(
            child: Text(
              'Aucun compte archivé',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView(
          children: archives
              .map(
                (compte) => Card(
                  color: const Color(0xFF232526),
                  child: ListTile(
                    leading: const Icon(Icons.archive, color: Colors.grey),
                    title: Text(compte.type),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(compte.nom),
                        if (compte.dateSuppression != null)
                          Text(
                            'Archivé le ${compte.dateSuppression!.day.toString().padLeft(2, '0')}/${compte.dateSuppression!.month.toString().padLeft(2, '0')}/${compte.dateSuppression!.year}',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.restore, color: Colors.green),
                      tooltip: 'Restaurer',
                      onPressed: () async {
                        await FirebaseService().updateCompte(compte.id, {
                          'estArchive': false,
                          'dateSuppression': null,
                        });
                      },
                    ),
                    onLongPress: () async {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) {
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.restore),
                                  title: const Text('Restaurer'),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await FirebaseService().updateCompte(
                                      compte.id,
                                      {
                                        'estArchive': false,
                                        'dateSuppression': null,
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildEnveloppesArchives() {
    return StreamBuilder<List<Categorie>>(
      stream: FirebaseService().lireCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'Aucune enveloppe à afficher',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        final enveloppesArchivees = <Map<String, dynamic>>[];
        for (final cat in snapshot.data!) {
          for (final env in cat.enveloppes) {
            if (env.archivee == true) {
              enveloppesArchivees.add({
                'categorie': cat.nom,
                'enveloppe': env,
                'categorieId': cat.id,
              });
            }
          }
        }

        if (enveloppesArchivees.isEmpty) {
          return const Center(
            child: Text(
              'Aucune enveloppe archivée',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return ListView(
          children: enveloppesArchivees.map((item) {
            final Enveloppe enveloppe = item['enveloppe'];
            return Card(
              color: const Color(0xFF232526),
              child: ListTile(
                leading: const Icon(Icons.archive, color: Colors.grey),
                title: Text(enveloppe.nom),
                subtitle: Text('Catégorie : ${item['categorie']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.restore, color: Colors.green),
                  tooltip: 'Restaurer',
                  onPressed: () async {
                    await FirebaseService().restaurerEnveloppe(
                      item['categorieId'],
                      enveloppe.id,
                    );
                  },
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

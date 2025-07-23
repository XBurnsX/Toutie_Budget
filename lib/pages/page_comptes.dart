import 'package:flutter/material.dart';
import 'package:toutie_budget/models/compte.dart';
import 'package:toutie_budget/models/dette.dart';
import 'package:toutie_budget/services/pocketbase_service.dart';
import 'package:toutie_budget/services/dette_service.dart';
import 'package:toutie_budget/services/cache_service.dart';
import 'page_creation_compte.dart';
import 'page_transactions_compte.dart';
import 'page_modification_compte.dart';
import 'page_reconciliation.dart';
import 'page_parametres_dettes.dart';
import 'page_pret_personnel.dart';
import 'page_investissement.dart';
import 'page_carte_de_credit.dart';
import 'package:toutie_budget/services/investissement_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PageComptes extends StatefulWidget {
  const PageComptes({super.key});

  @override
  State<PageComptes> createState() => _PageComptesState();
}

class _PageComptesState extends State<PageComptes> {
  bool _editionMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes comptes'),
        actions: [
          IconButton(
            tooltip: _editionMode ? 'Valider l\'ordre' : 'Réorganiser',
            icon: Icon(_editionMode ? Icons.check : Icons.swap_vert),
            onPressed: () => setState(() => _editionMode = !_editionMode),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Ajouter',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PageCreationCompte()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Compte>>(
        stream: PocketBaseService.lireTousLesComptes(),
        builder: (context, snapshot) {
          final comptes = (snapshot.data ?? [])
              .where((c) => c.estArchive == false)
              .toList()
            ..sort((a, b) => (a.ordre ?? 999999).compareTo(b.ordre ?? 999999));

          final cheques = comptes.where((c) => c.type == 'Chèque').toList();
          final credits =
              comptes.where((c) => c.type == 'Carte de crédit').toList();
          final dettesManuelles =
              comptes.where((c) => c.type == 'Dette').toList();
          final investissements =
              comptes.where((c) => c.type == 'Investissement').toList();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              _buildSection('Comptes chèques', Colors.blue, cheques),
              _buildSection('Cartes de crédit', Colors.purple, credits),
              // Section Dettes - combine les dettes manuelles et les dettes de la collection dettes
              _buildDettesSection(dettesManuelles),
              _buildSection('Investissement', Colors.green, investissements),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDettesSection(List<Compte> dettesManuelles) {
    return StreamBuilder<List<Dette>>(
      stream: DetteService().dettesActives(),
      builder: (context, dettesSnapshot) {
        final dettesActives = dettesSnapshot.data ?? [];
        // On récupère les IDs des dettes qui sont déjà gérées comme des comptes manuels
        final idsDettesManuelles = dettesManuelles.map((c) => c.id).toSet();

        // Filtrer pour n'afficher que les dettes contractées qui ne sont PAS déjà des comptes manuels
        final dettesAutomatiques = dettesActives
            .where(
              (d) => d.type == 'dette' && !idsDettesManuelles.contains(d.id),
            )
            .toList();

        final dettesAfficher = [
          ...dettesManuelles,
          ...dettesAutomatiques,
        ];

        if (dettesAfficher.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Text(
                'Dettes',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ),
            ...dettesAfficher.map((item) {
              if (item is Compte) {
                // Dette manuelle (compte)
                return _buildCard(item, Colors.red);
              } else if (item is Dette) {
                // Dette de la collection dettes
                return _buildDetteCard(item);
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildSection(String title, Color color, List<Compte> comptes) {
    if (comptes.isEmpty) return const SizedBox.shrink();

    if (_editionMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70)),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: comptes.length,
            onReorder: (oldIndex, newIndex) =>
                _reorder(comptes, oldIndex, newIndex),
            buildDefaultDragHandles: false,
            itemBuilder: (context, index) {
              final compte = comptes[index];
              return ReorderableDragStartListener(
                key: ValueKey(compte.id),
                index: index,
                child: _buildCard(compte, color, editing: true),
              );
            },
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70)),
          ),
          ...comptes.map((c) => _buildCard(c, color)),
        ],
      );
    }
  }

  Widget _buildCard(Compte compte, Color color, {bool editing = false}) {
    final isCheque = compte.type == 'Chèque';
    double cashDisponible = compte.pretAPlacer;
    if (compte.type == 'Investissement') {
      return FutureBuilder<Map<String, dynamic>>(
        future: InvestissementService().calculerPerformanceCompte(compte.id),
        builder: (context, snapshot) {
          double valeurActions = 0.0;
          if (snapshot.hasData) {
            valeurActions =
                (snapshot.data?['totalValeurActuelle'] ?? 0.0) as double;
          }
          final soldeAffiche = valeurActions + cashDisponible;
          return Container(
            key: ValueKey(compte.id),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              elevation: 2,
              color: const Color(0xFF232526),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: editing
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PageInvestissement(compteId: compte.id),
                          ),
                        );
                      },
                onLongPress: editing
                    ? null
                    : () => _showCompteMenu(context, compte, isCheque),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color(compte.couleur),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              compte.nom,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              compte.type,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          snapshot.connectionState == ConnectionState.waiting
                              ? SizedBox(
                                  width: 40,
                                  height: 16,
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)))
                              : Text(
                                  '${soldeAffiche.toStringAsFixed(2)} \$',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: soldeAffiche >= 0
                                        ? Colors.green
                                        : Colors.red[700],
                                  ),
                                ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(compte.couleur),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'CASH : ${cashDisponible.toStringAsFixed(2)} \$',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      editing
                          ? const Icon(Icons.drag_handle, color: Colors.white54)
                          : Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else if (compte.type == 'Carte de crédit') {
      // Affichage spécial pour carte de crédit : lire soldeActuel Firestore
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('comptes')
            .doc(compte.id)
            .get(),
        builder: (context, snapshot) {
          double soldeAffiche = compte.solde;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            soldeAffiche =
                -((data['soldeActuel'] as num?)?.toDouble() ?? compte.solde);
          }
          return Container(
            key: ValueKey(compte.id),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              elevation: 2,
              color: const Color(0xFF232526),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: editing
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PageDetailCarteCredit(
                                compteId: compte.id, nomCarte: compte.nom),
                          ),
                        );
                      },
                onLongPress: editing
                    ? null
                    : () => _showCompteMenu(context, compte, isCheque),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color(compte.couleur),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              compte.nom,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              compte.type,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${soldeAffiche.toStringAsFixed(2)} \$',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      editing
                          ? const Icon(Icons.drag_handle, color: Colors.white54)
                          : Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else {
      double soldeAffiche = compte.solde;
      if (compte.type == 'Investissement') {
        // On va chercher la valeur totale des actions + cash disponible
        // Pour l'instant, on affiche solde + cash, mais il faudrait idéalement requêter la vraie valeur des actions
        // (On peut améliorer avec un service ou un cache si besoin)
        // TODO: Remplacer par la vraie valeur des actions si dispo
        soldeAffiche = compte.solde + cashDisponible;
      }

      return Container(
        key: ValueKey(compte.id),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Card(
          elevation: 2,
          color: const Color(0xFF232526),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: editing
                ? null
                : () {
                    if (compte.type == 'Investissement') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PageInvestissement(compteId: compte.id),
                        ),
                      );
                    } else if (compte.type == 'Carte de crédit') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PageDetailCarteCredit(
                              compteId: compte.id, nomCarte: compte.nom),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PageTransactionsCompte(compte: compte),
                        ),
                      );
                    }
                  },
            onLongPress: editing
                ? null
                : () => _showCompteMenu(context, compte, isCheque),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(compte.couleur),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          compte.nom,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          compte.type,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${soldeAffiche.toStringAsFixed(2)} \$',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: soldeAffiche >= 0
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                      if (isCheque || compte.type == 'Investissement')
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(compte.couleur),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            compte.type == 'Investissement'
                                ? 'CASH : ${cashDisponible.toStringAsFixed(2)} \$'
                                : 'Prêt à placer: ${compte.pretAPlacer.toStringAsFixed(2)} \$',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  editing
                      ? const Icon(Icons.drag_handle, color: Colors.white54)
                      : Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildDetteCard(Dette dette) {
    final color = Colors.red; // Couleur rouge pour les dettes
    final isDetteManuelle =
        dette.estManuelle; // Vérifier si c'est une dette manuelle

    return Container(
      key: ValueKey(dette.id),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        color: const Color(0xFF232526),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _editionMode
              ? null
              : () {
                  // Navigation conditionnelle selon le type de dette
                  if (isDetteManuelle) {
                    // Dette manuelle → PageParametresDettes
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            PageParametresDettes(dette: dette),
                      ),
                    );
                  } else {
                    // Dette automatique → PagePretPersonnel (section Prêts & Dettes)
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PagePretPersonnel(),
                      ),
                    );
                  }
                },
          onLongPress:
              _editionMode ? null : null, // Pas de menu pour les dettes
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dette.type == 'dette'
                            ? 'Dette : ${dette.nomTiers}'
                            : 'Prêt à ${dette.nomTiers}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dette.type == 'dette'
                            ? 'Dette contractée'
                            : 'Prêt accordé',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      (dette.type == 'dette'
                          ? '-${dette.solde.abs().toStringAsFixed(2)} \$'
                          : '+${dette.solde.abs().toStringAsFixed(2)} \$'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: dette.type == 'dette'
                            ? Colors.red[700]
                            : Colors.green[700],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Initial: '
                        '${dette.type == 'dette' ? '-' : '+'}'
                        '${dette.montantInitial.abs().toStringAsFixed(2)} \$',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                _editionMode
                    ? const Icon(Icons.drag_handle, color: Colors.white54)
                    : Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reorder(
      List<Compte> section, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = section.removeAt(oldIndex);
    section.insert(newIndex, item);

    // Met à jour l\'ordre dans Firestore pour cette section uniquement.
    for (var i = 0; i < section.length; i++) {
      await PocketBaseService.updateCompte(section[i].id, {'ordre': i});
    }

    setState(() {}); // Rafraîchir l\'UI
  }

  void _showCompteMenu(BuildContext context, Compte compte, bool isCheque) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Modifier'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          PageModificationCompte(compte: compte),
                    ),
                  );
                },
              ),
              if (isCheque || compte.type == 'Carte de crédit')
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Réconcilier'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            PageReconciliation(compte: compte),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Supprimer',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, compte);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Compte compte) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer le compte "${compte.nom}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await PocketBaseService.updateCompte(compte.id, {
                    'estArchive': true,
                    'dateSuppression': DateTime.now().toIso8601String(),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Compte supprimé avec succès')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                }
              },
              child:
                  const Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:toutie_budget/pages/page_creation_compte.dart';
import 'package:toutie_budget/pages/page_transactions_compte.dart';
import 'package:toutie_budget/pages/page_modification_compte.dart';
import 'package:toutie_budget/pages/page_reconciliation.dart';
import 'package:toutie_budget/pages/page_pret_personnel.dart';
import 'package:toutie_budget/pages/page_parametres_dettes.dart';
import 'package:toutie_budget/services/firebase_service.dart';
import 'package:toutie_budget/services/dette_service.dart';
import 'package:toutie_budget/models/dette.dart';

import '../models/compte.dart';

/// Page d'affichage des comptes bancaires et d'investissement
class PageComptes extends StatelessWidget {
  const PageComptes({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Compte>>(
      stream: FirebaseService().lireComptes(),
      builder: (context, snapshot) {
        final comptes = (snapshot.data ?? [])
            .where((c) => c.estArchive == false)
            .toList();

        // Séparation par type
        final cheques = comptes.where((c) => c.type == 'Chèque').toList();
        final credits = comptes
            .where((c) => c.type == 'Carte de crédit')
            .toList();
        final dettesManuelles = comptes
            .where((c) => c.type == 'Dette')
            .toList();
        final investissements = comptes
            .where((c) => c.type == 'Investissement')
            .toList();

        return Column(
          children: [
            SizedBox(height: 45),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mes comptes',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PageCreationCompte(),
                        ),
                      );
                    },
                    icon: Icon(Icons.add),
                    label: Text('Ajouter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (cheques.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        'Comptes chèques',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    ...cheques.map(
                      (compte) =>
                          _buildCompteCard(compte, Colors.blue, context, true),
                    ),
                    SizedBox(height: 24),
                  ],
                  if (credits.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        'Cartes de crédit',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    ...credits.map(
                      (compte) => _buildCompteCard(
                        compte,
                        Colors.purple,
                        context,
                        false,
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                  // Section Dettes - combine les dettes manuelles et les dettes de la collection dettes
                  StreamBuilder<List<Dette>>(
                    stream: DetteService().dettesActives(),
                    builder: (context, dettesSnapshot) {
                      final dettesActives = dettesSnapshot.data ?? [];
                      // On récupère les IDs des dettes qui sont déjà gérées comme des comptes manuels
                      final idsDettesManuelles = dettesManuelles
                          .map((c) => c.id)
                          .toSet();

                      // Filtrer pour n'afficher que les dettes contractées qui ne sont PAS déjà des comptes manuels
                      final dettesAutomatiques = dettesActives
                          .where(
                            (d) =>
                                d.type == 'dette' &&
                                !idsDettesManuelles.contains(d.id),
                          )
                          .toList();

                      final dettesAfficher = [
                        ...dettesManuelles,
                        ...dettesAutomatiques,
                      ];

                      // Debug silencieux

                      if (dettesAfficher.isNotEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Text(
                                'Dettes',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            ...dettesAfficher.map((item) {
                              if (item is Compte) {
                                // Dette manuelle (compte)
                                return _buildCompteCard(
                                  item,
                                  Colors.red,
                                  context,
                                  false,
                                );
                              } else if (item is Dette) {
                                // Dette de la collection dettes
                                return _buildDetteCard(item, context);
                              }
                              return SizedBox.shrink();
                            }),
                            SizedBox(height: 24),
                          ],
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),
                  if (investissements.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        'Comptes d\'investissement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    ...investissements.map(
                      (compte) => _buildCompteCard(
                        compte,
                        Colors.green,
                        context,
                        false,
                      ),
                    ),
                  ],
                  if (comptes.isEmpty && (snapshot.data ?? []).isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'Aucun compte pour le moment.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompteCard(
    Compte compte,
    Color defaultColor,
    BuildContext context,
    bool isCheque,
  ) {
    final color = Color(compte.couleur);
    final isDette = compte.type == 'Dette';

    // Pour les dettes, le solde affiché est toujours celui du compte
    final soldeAffiche = compte.solde;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        color: const Color(0xFF232526), // Même couleur que les enveloppes
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            if (isDette) {
              // Pour une dette manuelle, on doit récupérer l'objet Dette complet
              // pour passer toutes les infos à la page des paramètres.
              final dette = await DetteService().getDette(compte.id);

              if (dette != null && context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PageParametresDettes(dette: dette),
                  ),
                );
              } else if (context.mounted) {
                // Fallback si la dette n'existe pas encore dans la collection 'dettes'
                final detteManuelle = Dette(
                  id: compte.id,
                  nomTiers: compte.nom,
                  type: 'dette',
                  montantInitial: compte.solde.abs(),
                  solde: soldeAffiche,
                  historique: [],
                  archive: false,
                  dateCreation: DateTime.now(),
                  userId: '',
                  estManuelle: true,
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        PageParametresDettes(dette: detteManuelle),
                  ),
                );
              }
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PageTransactionsCompte(compte: compte),
                ),
              );
            }
          },
          onLongPress: () => _showCompteMenu(context, compte, isCheque),
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
                        compte.nom,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        compte.type,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                    if (isCheque)
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
                          'Prêt à placer: ${compte.pretAPlacer.toStringAsFixed(2)} \$',
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
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
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
                title: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
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
            'Êtes-vous sûr de vouloir supprimer le compte "${compte.nom}" ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  // Archiver le compte en utilisant updateCompte
                  await FirebaseService().updateCompte(compte.id, {
                    'estArchive': true,
                    'dateSuppression': DateTime.now().toIso8601String(),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Compte supprimé avec succès'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }
              },
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetteCard(Dette dette, BuildContext context) {
    final color = Colors.red; // Couleur rouge pour les dettes
    final isDetteManuelle =
        dette.estManuelle; // Vérifier si c'est une dette manuelle

    // Debug silencieux

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        color: const Color(0xFF232526), // Même couleur que les enveloppes
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Navigation conditionnelle selon le type de dette
            if (isDetteManuelle) {
              // Dette manuelle → PageParametresDettes
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PageParametresDettes(dette: dette),
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
          onLongPress: () {
            // Pas de menu pour les dettes automatiques
          },
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
                Icon(
                  isDetteManuelle ? Icons.settings : Icons.account_balance,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

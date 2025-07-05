import 'package:flutter/material.dart';
import 'package:toutie_budget/pages/page_creation_compte.dart';
import 'package:toutie_budget/pages/page_transactions_compte.dart';
import 'package:toutie_budget/pages/page_modification_compte.dart';
import 'package:toutie_budget/pages/page_reconciliation.dart';
import 'package:toutie_budget/pages/page_pret_personnel.dart';
import 'package:toutie_budget/pages/page_parametres_dettes.dart';
import 'package:toutie_budget/pages/page_investissement.dart';
import 'package:toutie_budget/services/firebase_service.dart';
import 'package:toutie_budget/services/dette_service.dart';
import 'package:toutie_budget/models/dette.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/compte.dart';
import '../services/firebase_monitor_service.dart';

/// Page d'affichage des comptes bancaires et d'investissement
class PageComptes extends StatelessWidget {
  const PageComptes({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mes comptes'),
          elevation: 0,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _buildComptesContent(context),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes comptes'),
        elevation: 0,
      ),
      body: _buildComptesContent(context),
    );
  }

  Widget _buildComptesContent(BuildContext context) {
    return StreamBuilder<List<Compte>>(
      stream: FirebaseService().lireComptes(),
      builder: (context, snapshot) {
        print('=== STREAMBUILDER COMPTES ===');
        print('HasData: ${snapshot.hasData}');
        print('HasError: ${snapshot.hasError}');
        print('Error: ${snapshot.error}');
        print('Data length: ${snapshot.data?.length ?? 0}');

        final comptes =
            (snapshot.data ?? []).where((c) => c.estArchive == false).toList();

        print('Comptes non archivés: ${comptes.length}');
        for (var compte in comptes) {
          print(
              '- ${compte.nom} (${compte.type}) - Archivé: ${compte.estArchive}');
        }

        // Séparation par type
        final cheques = comptes.where((c) => c.type == 'Chèque').toList();
        final credits =
            comptes.where((c) => c.type == 'Carte de crédit').toList();
        final dettesManuelles =
            comptes.where((c) => c.type == 'Dette').toList();
        final investissements =
            comptes.where((c) => c.type == 'Investissement').toList();

        return Column(
          children: [
            if (!kIsWeb) SizedBox(height: 45),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!kIsWeb)
                    Text(
                      'Mes comptes',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                      final idsDettesManuelles =
                          dettesManuelles.map((c) => c.id).toSet();

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
        color: const Color(0xFF313334),
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
            } else if (compte.type == 'Investissement') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PageInvestissement(compteId: compte.id),
                ),
              );
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
    print('=== MENU COMPTE OUVERT ===');
    print('Compte: ${compte.nom}');
    print('Type: ${compte.type}');
    print('ID: ${compte.id}');
    print('IsCheque: $isCheque');

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
                  print('=== BOUTON SUPPRIMER CLIQUÉ ===');
                  print('Compte: ${compte.nom}');
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
    print('=== CONFIRMATION SUPPRESSION ===');
    print('Compte à supprimer: ${compte.nom}');
    print('Type: ${compte.type}');
    print('ID: ${compte.id}');

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
                  print('=== DÉBUT SUPPRESSION ===');
                  print('Type de compte: ${compte.type}');
                  print('Nom du compte: ${compte.nom}');
                  print('ID du compte: ${compte.id}');
                  print('Est archivé actuellement: ${compte.estArchive}');

                  // Logger la suppression
                  final user = FirebaseService().auth.currentUser;
                  final userId = user?.uid ?? 'anonymous';
                  print('Utilisateur connecté: $userId');

                  FirebaseMonitorService.logWrite(
                    collection: 'comptes',
                    document: compte.id,
                    count: 1,
                    userId: userId,
                    details:
                        'Suppression/archivage du compte: ${compte.nom} (Type: ${compte.type})',
                  );

                  print('Tentative d\'archivage...');

                  // Utiliser la même logique d'archivage pour tous les types de comptes
                  await FirebaseService().updateCompte(compte.id, {
                    'estArchive': true,
                    'dateSuppression': DateTime.now().toIso8601String(),
                  });

                  print('=== SUPPRESSION RÉUSSIE ===');
                  print('Compte supprimé avec succès: ${compte.nom}');
                  print('Type de compte: ${compte.type}');
                  print('ID du compte: ${compte.id}');

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Compte ${compte.nom} supprimé avec succès'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  print('=== ERREUR DE SUPPRESSION ===');
                  print('Erreur lors de la suppression: $e');
                  print('Type d\'erreur: ${e.runtimeType}');
                  print('Stack trace: ${StackTrace.current}');

                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(
                      content: Text('Erreur lors de la suppression: $e'),
                      backgroundColor: Colors.red,
                    ));
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
        color: const Color(0xFF313334),
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

class CompteCardWidget extends StatelessWidget {
  final Compte compte;
  final Color defaultColor;
  final BuildContext contextParent;
  final bool isCheque;
  final void Function()? onTap;
  final void Function()? onLongPress;

  const CompteCardWidget({
    super.key,
    required this.compte,
    required this.defaultColor,
    required this.contextParent,
    required this.isCheque,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(compte.couleur);
    final isDette = compte.type == 'Dette';
    final soldeAffiche = compte.solde;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        color: const Color(0xFF313334),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
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
}

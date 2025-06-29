import 'package:flutter/material.dart';
import 'package:toutie_budget/pages/page_creation_compte.dart';
import 'package:toutie_budget/pages/page_transactions_compte.dart';
import 'package:toutie_budget/pages/page_modification_compte.dart';
import 'package:toutie_budget/pages/page_reconciliation.dart';
import 'package:toutie_budget/pages/page_pret_personnel.dart'; // Ajouter l'import pour la page prêt personnel
import 'package:toutie_budget/services/firebase_service.dart';

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
        final dettes = comptes.where((c) => c.type == 'Dette').toList();
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
                  if (dettes.isNotEmpty) ...[
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
                    ...dettes.map(
                      (compte) =>
                          _buildCompteCard(compte, Colors.red, context, false),
                    ),
                    SizedBox(height: 24),
                  ],
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
                  if (comptes.isEmpty)
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
    // Détecter les comptes automatiques par leur nom et par detteAssocieeId
    final isDetteAutomatique =
        compte.type == 'Dette' &&
        (compte.detteAssocieeId != null || compte.nom.startsWith("Prêt : "));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Navigation différentielle selon le type de compte de dette
            if (isDetteAutomatique) {
              // Compte de dette automatique (créé via prêt personnel) -> Page prêt personnel
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PagePretPersonnel(),
                ),
              );
            } else {
              // Tous les autres comptes (y compris dettes manuelles) -> Page transactions du compte
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PageTransactionsCompte(compte: compte),
                ),
              );
            }
          },
          onLongPress: () {
            // Menu CRUD pour tous les comptes (sauf dettes automatiques)
            if (!isDetteAutomatique) {
              _showCompteMenu(context, compte, isCheque);
            }
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
                      if (isDetteAutomatique)
                        Text(
                          'Géré via Prêts Personnels',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${compte.solde.toStringAsFixed(2)} \$',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: compte.solde >= 0
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    ),
                    if (isCheque && compte.pretAPlacer > 0)
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
                Icon(
                  isDetteAutomatique
                      ? Icons.account_balance
                      : Icons.chevron_right,
                  color: Colors.grey[400],
                ),
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
}

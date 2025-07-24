import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'pie_chart_with_legend.dart';
import 'package:toutie_budget/widgets/assignation_bottom_sheet.dart';
import 'package:toutie_budget/services/argent_service.dart';

/// Widget pour afficher dynamiquement les catégories et enveloppes
class ListeCategoriesEnveloppes extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> comptes;
  final bool editionMode;
  final void Function(String catId, String envId)? onRename;
  final void Function(String catId, String envId)? onDelete;
  final String? selectedMonthKey;

  const ListeCategoriesEnveloppes({
    super.key,
    required this.categories,
    required this.comptes,
    this.editionMode = false,
    this.onRename,
    this.onDelete,
    this.selectedMonthKey,
  });

  @override
  State<ListeCategoriesEnveloppes> createState() =>
      _ListeCategoriesEnveloppesState();
}

class _ListeCategoriesEnveloppesState extends State<ListeCategoriesEnveloppes> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ListeCategoriesEnveloppes oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Plus besoin de recharger les données car on affiche tout directement
  }

  List<Map<String, dynamic>> _getSortedCategories() {
    final sortedCategories = List<Map<String, dynamic>>.from(widget.categories);
    sortedCategories.sort((a, b) {
      final aNom = (a['nom'] as String).toLowerCase();
      final bNom = (b['nom'] as String).toLowerCase();
      if (aNom == 'dette' || aNom == 'dettes') return -1;
      if (bNom == 'dette' || bNom == 'dettes') return 1;
      final aOrdre = (a['ordre'] as int?) ?? 999999;
      final bOrdre = (b['ordre'] as int?) ?? 999999;
      return aOrdre.compareTo(bOrdre);
    });
    return sortedCategories;
  }

  void _showViderEnveloppeMenu(
      BuildContext context, Map<String, dynamic> enveloppe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Vider l\'enveloppe "${enveloppe['nom']}" ?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Cette action va vider l\'enveloppe et retourner ${(enveloppe['solde'] ?? 0.0).toStringAsFixed(2)} \$ dans le prêt à placer du compte d\'origine.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _viderEnveloppe(enveloppe);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Vider',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _viderEnveloppe(Map<String, dynamic> enveloppe) async {
    try {
      await ArgentService().viderEnveloppe(enveloppeId: enveloppe['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enveloppe "${enveloppe['nom']}" vidée avec succès',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String messageErreur = 'Erreur lors du vidage';

        if (e.toString().contains('Enveloppe non trouvée')) {
          messageErreur = 'Enveloppe non trouvée dans la base de données';
        } else if (e.toString().contains('déjà vide')) {
          messageErreur = 'L\'enveloppe est déjà vide';
        } else if (e.toString().contains('Aucune provenance trouvée')) {
          messageErreur = 'Aucune provenance trouvée pour cette enveloppe';
        } else if (e.toString().contains('Catégorie non trouvée')) {
          messageErreur = 'Catégorie non trouvée dans la base de données';
        } else if (e.toString().contains('Index d\'enveloppe invalide')) {
          messageErreur = 'Erreur interne : index d\'enveloppe invalide';
        } else {
          messageErreur = 'Erreur lors du vidage : ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              messageErreur,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Color _getEtatColor(double solde, double objectif) {
    if (solde < 0) return Colors.red;
    if (objectif == 0) return Colors.grey;
    if (solde >= objectif) return Colors.green;
    if (solde >= objectif * 0.7) return Colors.yellow;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _getSortedCategories().length,
      itemBuilder: (context, index) {
        final categorie = _getSortedCategories()[index];
        
        final toutesEnveloppes = (categorie['enveloppes'] as List<Map<String, dynamic>>);

        final enveloppes = toutesEnveloppes
            .where((env) => env['archivee'] != true)
            .toList();

        // --- LOGIQUE SPÉCIALE POUR DETTE ---
        if ((categorie['nom'] as String).toLowerCase().contains('dette')) {
          // 1. Récupérer tous les comptes de type Carte de crédit/crédit
          final cartesCredit = widget.comptes.where((c) {
            final type = (c['type'] ?? '').toString().toLowerCase();
            return type.contains('carte') || type.contains('crédit');
          }).toList();

          // 2. Noms des enveloppes déjà présentes (normalisés)
          String normalize(String s) => s.toLowerCase().trim();
          final nomsEnveloppes =
              enveloppes.map((e) => normalize(e['nom'] ?? '')).toSet();

          // 3. Créer des enveloppes virtuelles pour les cartes de crédit manquantes
          final enveloppesVirtuelles = cartesCredit
              .where((c) => !nomsEnveloppes.contains(normalize(c['nom'] ?? '')))
              .map((c) => {
                    'nom': c['nom'],
                    'solde': 0.0,
                    'objectif': 0.0,
                    'depense': 0.0,
                    'provenance_compte_id': c['id'],
                    'archivee': false,
                    'provenances': [],
                  })
              .toList();

          // 4. Filtrer toutes les enveloppes pour ne garder qu'une seule par nom (normalisé)
          final Set<String> nomsVus = enveloppesVirtuelles
              .map((e) => normalize(e['nom'] ?? ''))
              .toSet();
          final enveloppesUniques = <Map<String, dynamic>>[];
          for (final env in enveloppes) {
            final nomNorm = normalize(env['nom'] ?? '');
            if (!nomsVus.contains(nomNorm)) {
              enveloppesUniques.add(env);
              nomsVus.add(nomNorm);
            }
          }

          // 5. Afficher d'abord les enveloppes virtuelles (cartes de crédit sans enveloppe), puis les enveloppes existantes uniques
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    categorie['nom'],
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              ...enveloppesVirtuelles
                  .map((env) => _buildEnveloppeWidget(env, categorie)),
              ...enveloppesUniques.map(
                  (enveloppe) => _buildEnveloppeWidget(enveloppe, categorie)),
              const SizedBox(height: 24),
            ],
          );
        }
        // --- FIN LOGIQUE SPÉCIALE DETTE ---

        // Vérifier si la catégorie a des enveloppes négatives
        final aEnveloppesNegatives = enveloppes.any(
          (env) => (env['solde'] ?? 0.0).toDouble() < 0,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icône d'avertissement pour les catégories avec enveloppes négatives
                if (aEnveloppesNegatives) ...[
                  Icon(Icons.warning, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  categorie['nom'],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: aEnveloppesNegatives
                        ? Colors.red[400]
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            ...enveloppes.map((enveloppe) => _buildEnveloppeWidget(enveloppe, categorie)),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildEnveloppeWidget(
      Map<String, dynamic> enveloppe, Map<String, dynamic> categorie) {
    // --- Logique d'affichage de l'historique ---
    Map<String, dynamic> historique = enveloppe['historique'] != null
        ? Map<String, dynamic>.from(enveloppe['historique'])
        : {};
    Map<String, dynamic>? histoMois =
        (widget.selectedMonthKey != null &&
                historique[widget.selectedMonthKey] != null)
            ? Map<String, dynamic>.from(
                historique[widget.selectedMonthKey])
            : null;

    final now = DateTime.now();
    final currentMonthKey =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
    final selectedDate = widget.selectedMonthKey != null
        ? DateFormat('yyyy-MM').parse(widget.selectedMonthKey!)
        : now;
    final isFutureMonth = selectedDate.year > now.year ||
        (selectedDate.year == now.year &&
            selectedDate.month > now.month);

    double soldeEnveloppe;
    double objectif;
    double depense;

    if (widget.selectedMonthKey == null ||
        widget.selectedMonthKey == currentMonthKey) {
      // Mois courant -> valeurs globales
      soldeEnveloppe = (enveloppe['solde_enveloppe'] ?? 0.0).toDouble();
      objectif = (enveloppe['objectif_montant'] ?? 0.0).toDouble();
      depense = (enveloppe['depense'] ?? 0.0).toDouble();
    } else if (histoMois != null) {
      // Mois passé avec historique -> valeurs de l'historique
      soldeEnveloppe = (histoMois['solde'] ?? 0.0).toDouble();
      objectif = (histoMois['objectif'] ?? 0.0).toDouble();
      depense = (histoMois['depense'] ?? 0.0).toDouble();
    } else if (isFutureMonth) {
      // Mois futur -> valeurs projetées
      soldeEnveloppe = (enveloppe['solde_enveloppe'] ?? 0.0).toDouble();
      objectif = (enveloppe['objectif_montant'] ?? 0.0).toDouble();
      depense = 0.0;
    } else {
      // Mois passé sans historique -> 0
      soldeEnveloppe = 0.0;
      objectif = 0.0;
      depense = 0.0;
    }

    final bool estNegative = soldeEnveloppe < 0;
    final bool estDepenseAtteint = (depense >= objectif && objectif > 0);
    final double progression = (objectif > 0)
        ? (estDepenseAtteint ? 1.0 : (soldeEnveloppe / objectif).clamp(0.0, 1.0))
        : 0.0;
    final Color etatColor = _getEtatColor(soldeEnveloppe, objectif);

    // --- Widget bulle enveloppe interactif ---
    Color bulleColor;
    final String compteId = enveloppe['compte_provenance_id'] ?? '';
    if (soldeEnveloppe == 0) {
      bulleColor = const Color(0xFF44474A);
    } else if (estNegative) {
      bulleColor = Colors.red;
    } else if (compteId.isNotEmpty) {
      final compte = widget.comptes.firstWhere(
        (c) => c['id'].toString() == compteId.toString(),
        orElse: () => <String, Object>{},
      );
      if (compte['couleur'] != null && compte['couleur'] is int) {
        try {
          bulleColor = Color(compte['couleur'] as int);
        } catch (_) {
          bulleColor = Colors.amber;
        }
      } else {
        bulleColor = Colors.amber;
      }
    } else {
      bulleColor = Colors.amber;
    }

    final cardWidget = Card(
      color: estNegative
          ? Theme.of(context).colorScheme.error.withValues(alpha: 0.15)
          : const Color(0xFF232526),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icône d'avertissement pour les enveloppes négatives
            if (estNegative) ...[
              Icon(Icons.warning, color: Colors.red[700], size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                enveloppe['nom'],
                style: TextStyle(
                  color: estNegative ? Colors.red[800] : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Bulle colorée avec le montant dedans
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: bulleColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${soldeEnveloppe.toStringAsFixed(2)}\$',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return widget.editionMode
        ? cardWidget
        : InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => AssignationBottomSheet(
                  enveloppe: enveloppe,
                  comptes: widget.comptes,
                ),
              );
            },
            onLongPress: () {
              if (soldeEnveloppe > 0) {
                _showViderEnveloppeMenu(context, enveloppe);
              }
            },
            child: cardWidget,
          );
  }
}

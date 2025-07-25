import 'package:flutter/material.dart';
import 'package:toutie_budget/services/allocation_service.dart';
import 'package:toutie_budget/services/argent_service.dart';
import 'package:toutie_budget/widgets/enveloppe_widget.dart';

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
  List<Map<String, dynamic>>? _cachedSortedCategories;
  int _lastCategoriesHashCode = 0;

  // Cache des soldes des enveloppes pour éviter les appels multiples
  final Map<String, double?> _soldesCache = {};
  final Map<String, Future<double?>> _pendingSoldesFutures = {};

  @override
  void initState() {
    super.initState();
    _updateCachedCategories();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ListeCategoriesEnveloppes oldWidget) {
    super.didUpdateWidget(oldWidget);

    // SOLUTION: Ignorer complètement les mises à jour temps réel PocketBase
    // Le cache intelligent des soldes évite déjà les appels inutiles

    // Seule exception: changement de mois sélectionné par l'utilisateur
    if (oldWidget.selectedMonthKey != widget.selectedMonthKey) {
      _soldesCache.clear();
      _pendingSoldesFutures.clear();
    }

    // Tout le reste est géré par le cache des soldes qui évite les calculs redondants
  }

  // Méthode pour obtenir le solde d'une enveloppe avec cache
  Future<double?> _getSoldeEnveloppe(String enveloppeId, DateTime moisAllocation) async {
    final cacheKey = '${enveloppeId}_${moisAllocation.toIso8601String()}';

    // Vérifier si le solde est déjà en cache
    if (_soldesCache.containsKey(cacheKey)) {
      return _soldesCache[cacheKey];
    }

    // Vérifier si une requête est déjà en cours
    if (_pendingSoldesFutures.containsKey(cacheKey)) {
      return await _pendingSoldesFutures[cacheKey]!;
    }

    // Créer une nouvelle requête
    final future = AllocationService.calculerSoldeEnveloppe(
      enveloppeId: enveloppeId,
      mois: moisAllocation,
    );

    _pendingSoldesFutures[cacheKey] = future;

    try {
      final solde = await future;
      _soldesCache[cacheKey] = solde;
      _pendingSoldesFutures.remove(cacheKey);
      return solde;
    } catch (e) {
      _pendingSoldesFutures.remove(cacheKey);
      rethrow;
    }
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

  void _updateCachedCategories() {
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

    setState(() {
      _cachedSortedCategories = sortedCategories;
      _lastCategoriesHashCode = widget.categories.hashCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _cachedSortedCategories?.length ?? 0,
      itemBuilder: (context, index) {
        final categorie = _cachedSortedCategories![index];

        final toutesEnveloppes =
            (categorie['enveloppes'] as List<Map<String, dynamic>>);

        final enveloppes =
            toutesEnveloppes.where((env) => env['archivee'] != true).toList();

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
              ...enveloppesVirtuelles.map((env) => EnveloppeWidget(
                    key: ValueKey(env['id'] ?? env['nom']),
                    enveloppe: env,
                    categorie: categorie,
                    comptes: widget.comptes,
                    selectedMonthKey: widget.selectedMonthKey,
                    editionMode: widget.editionMode,
                    showViderEnveloppeMenu: _showViderEnveloppeMenu,
                    getSoldeEnveloppe: _getSoldeEnveloppe,
                    onAssignationComplete: () => setState(() {}),
                  )),
              ...enveloppesUniques.map((enveloppe) => EnveloppeWidget(
                    key: ValueKey(enveloppe['id']),
                    enveloppe: enveloppe,
                    categorie: categorie,
                    comptes: widget.comptes,
                    selectedMonthKey: widget.selectedMonthKey,
                    editionMode: widget.editionMode,
                    showViderEnveloppeMenu: _showViderEnveloppeMenu,
                    getSoldeEnveloppe: _getSoldeEnveloppe,
                    onAssignationComplete: () => setState(() {}),
                  )),
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
            ...enveloppes.map((enveloppe) => EnveloppeWidget(
                  key: ValueKey(enveloppe['id']),
                  enveloppe: enveloppe,
                  categorie: categorie,
                  comptes: widget.comptes,
                  selectedMonthKey: widget.selectedMonthKey,
                  editionMode: widget.editionMode,
                  showViderEnveloppeMenu: _showViderEnveloppeMenu,
                  getSoldeEnveloppe: _getSoldeEnveloppe,
                  onAssignationComplete: () => setState(() {}),
                )),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

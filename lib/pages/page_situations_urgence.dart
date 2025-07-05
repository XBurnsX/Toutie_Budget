import 'package:flutter/material.dart';
import '../models/compte.dart';
import '../models/categorie.dart';
import '../services/firebase_service.dart';
import '../services/cache_service.dart';
import 'page_virer_argent.dart';

/// Page pour afficher et gérer les enveloppes en situation d'urgence (solde négatif)
class PageSituationsUrgence extends StatelessWidget {
  const PageSituationsUrgence({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Situations d\'urgence'),
        elevation: 0,
      ),
      body: FutureBuilder<List<Compte>>(
        future: CacheService.getComptes(FirebaseService()),
        builder: (context, comptesSnapshot) {
          return FutureBuilder<List<Categorie>>(
            future: CacheService.getCategories(FirebaseService()),
            builder: (context, catSnapshot) {
              if (!comptesSnapshot.hasData || !catSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final comptes = comptesSnapshot.data!;
              final categories = catSnapshot.data!;

              // Filtrer les comptes avec prêt à placer négatif
              final comptesNegatifs = comptes
                  .where(
                    (compte) =>
                        compte.pretAPlacer < 0 &&
                        compte.type != 'Dette' &&
                        compte.type != 'Investissement',
                  )
                  .toList();

              // Filtrer les catégories qui ont des enveloppes négatives
              final categoriesAvecEnveloppesNegatives =
                  <Map<String, dynamic>>[];

              for (var categorie in categories) {
                final enveloppesNegatives =
                    categorie.enveloppes.where((env) => env.solde < 0).toList();
                if (enveloppesNegatives.isNotEmpty) {
                  categoriesAvecEnveloppesNegatives.add({
                    'id': categorie.id,
                    'nom': categorie.nom,
                    'enveloppes':
                        enveloppesNegatives.map((e) => e.toMap()).toList(),
                  });
                }
              }

              if (comptesNegatifs.isEmpty &&
                  categoriesAvecEnveloppesNegatives.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 64),
                      SizedBox(height: 16),
                      Text(
                        'Aucune situation d\'urgence !',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tous vos comptes et enveloppes sont en positif.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Bandeau d'information
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      border: Border.all(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: Colors.red[700],
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Actions nécessaires',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tapez sur une enveloppe pour la renflouer directement.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  // Comptes négatifs
                  if (comptesNegatifs.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Comptes en négatif',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...comptesNegatifs.map(
                      (compte) => Container(
                        width: MediaQuery.of(context).size.width * 0.92,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          borderRadius: const BorderRadius.all(
                            Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(64),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  compte.nom,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Prêt à placer',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  '${compte.pretAPlacer.toStringAsFixed(2)} \$',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Enveloppes négatives
                  if (categoriesAvecEnveloppesNegatives.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Enveloppes en négatif',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: UrgencyListeCategoriesEnveloppes(
                        categories: categoriesAvecEnveloppesNegatives,
                        comptes: comptes
                            .map(
                              (compte) => {
                                'id': compte.id,
                                'couleur': compte.couleur,
                              },
                            )
                            .toList(),
                        onEnveloppePressed: (enveloppeId) {
                          // Trouver l'enveloppe pour récupérer son solde négatif
                          double montantNegatif = 0.0;
                          for (var cat in categoriesAvecEnveloppesNegatives) {
                            final enveloppes =
                                cat['enveloppes'] as List<Map<String, dynamic>>;
                            final enveloppe = enveloppes.firstWhere(
                              (env) => env['id'] == enveloppeId,
                              orElse: () => <String, dynamic>{},
                            );
                            if (enveloppe.isNotEmpty) {
                              montantNegatif =
                                  (enveloppe['solde'] ?? 0.0).toDouble().abs();
                              break;
                            }
                          }

                          // Rediriger vers la page de virement avec l'enveloppe et le montant pré-sélectionnés
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PageVirerArgent(
                                destinationPreselectionnee: enveloppeId,
                                montantPreselectionne: montantNegatif,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Widget spécialisé pour afficher les enveloppes négatives avec possibilité de clic
class UrgencyListeCategoriesEnveloppes extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> comptes;
  final Function(String) onEnveloppePressed;

  const UrgencyListeCategoriesEnveloppes({
    super.key,
    required this.categories,
    required this.comptes,
    required this.onEnveloppePressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final categorie = categories[index];
        final enveloppes =
            categorie['enveloppes'] as List<Map<String, dynamic>>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  categorie['nom'],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            ...enveloppes.map((enveloppe) {
              final solde = (enveloppe['solde'] ?? 0.0).toDouble();

              return Card(
                color: Colors.red[50],
                child: InkWell(
                  onTap: () => onEnveloppePressed(enveloppe['id']),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.red, width: 8),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red[700], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  enveloppe['nom'],
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tapez pour renflouer',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${solde.toStringAsFixed(2)} \$',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.red[700],
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

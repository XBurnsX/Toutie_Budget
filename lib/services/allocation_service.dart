// 📁 Chemin : lib/services/allocation_service.dart
// 🔗 Dépendances : pocketbase, auth_service, allocation_mensuelle
// 📋 Description : Service dédié aux allocations mensuelles

import 'package:pocketbase/pocketbase.dart';
import '../models/allocation_mensuelle.dart';
import 'auth_service.dart';

class AllocationService {
  static final AllocationService _instance = AllocationService._internal();
  factory AllocationService() => _instance;
  AllocationService._internal();

  // Obtenir l'instance PocketBase depuis AuthService
  static Future<PocketBase> _getPocketBaseInstance() async {
    final authServiceInstance = AuthService.pocketBaseInstance;
    if (authServiceInstance != null) {
      return authServiceInstance;
    }
    throw Exception('❌ Instance PocketBase non disponible');
  }

  // Créer une nouvelle allocation mensuelle (placer/retirer de l'argent)
  static Future<void> creerAllocationMensuelle({
    required String enveloppeId,
    required double montant,
    required String compteSourceId,
    required String collectionCompteSource,
    required bool estAllocation, // true = allocation, false = retrait
  }) async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) return;

      // Date du 1er du mois actuel à 00h00
      final maintenant = DateTime.now();
      final premierDuMois = DateTime(maintenant.year, maintenant.month, 1);

      // Chercher l'allocation existante pour ce mois
      final allocations = await pb.collection('allocations_mensuelles').getList(
            filter:
                'enveloppe_id = "$enveloppeId" && mois = "${premierDuMois.toIso8601String()}" && utilisateur_id = "$userId"',
          );

      if (allocations.items.isNotEmpty) {
        // Mettre à jour l'allocation existante
        final allocation = allocations.items.first;
        final donnees = allocation.data;

        double nouveauSolde = (donnees['solde'] ?? 0).toDouble();
        double nouveauAlloue = (donnees['alloue'] ?? 0).toDouble();

        if (estAllocation) {
          // Placer de l'argent dans l'enveloppe
          nouveauSolde += montant;
          nouveauAlloue += montant;
        } else {
          // Retirer de l'argent de l'enveloppe
          nouveauSolde -= montant;
          nouveauAlloue -= montant;
        }

        await pb
            .collection('allocations_mensuelles')
            .update(allocation.id, body: {
          'solde': nouveauSolde,
          'alloue': nouveauAlloue,
        });

        // Synchroniser l'enveloppe après update
        await synchroniserEnveloppeDepuisAllocations(enveloppeId);
      } else {
        // Créer une nouvelle allocation
        final nouvelleAllocation = {
          'utilisateur_id': userId,
          'enveloppe_id': enveloppeId,
          'mois': premierDuMois.toIso8601String(),
          'solde': estAllocation ? montant : -montant,
          'alloue': estAllocation ? montant : -montant,
          'depense': 0.0,
          'compte_source_id': compteSourceId,
          'collection_compte_source': collectionCompteSource,
        };

        await pb
            .collection('allocations_mensuelles')
            .create(body: nouvelleAllocation);
        // Synchroniser l'enveloppe après création
        await synchroniserEnveloppeDepuisAllocations(enveloppeId);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Mettre à jour une allocation pour une transaction (solde et depense seulement)
  static Future<void> mettreAJourAllocationPourTransaction({
    required String enveloppeId,
    required double montant,
    required bool estDepense, // true = dépense, false = entrée
  }) async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) return;

      // Date du 1er du mois actuel à 00h00
      final maintenant = DateTime.now();
      final premierDuMois = DateTime(maintenant.year, maintenant.month, 1);

      // Chercher l'allocation existante pour ce mois
      final allocations = await pb.collection('allocations_mensuelles').getList(
            filter:
                'enveloppe_id = "$enveloppeId" && mois = "${premierDuMois.toIso8601String()}" && utilisateur_id = "$userId"',
          );

      if (allocations.items.isNotEmpty) {
        // Mettre à jour l'allocation existante
        final allocation = allocations.items.first;
        final donnees = allocation.data;

        double nouveauSolde = (donnees['solde'] ?? 0).toDouble();
        double nouvelleDepense = (donnees['depense'] ?? 0).toDouble();

        if (estDepense) {
          // Dépense
          nouveauSolde -= montant;
          nouvelleDepense += montant;
        } else {
          // Entrée
          nouveauSolde += montant;
          nouvelleDepense -= montant; // Réduire les dépenses
        }

        await pb
            .collection('allocations_mensuelles')
            .update(allocation.id, body: {
          'solde': nouveauSolde,
          'depense': nouvelleDepense,
        });

        // Synchroniser l'enveloppe après update
        await synchroniserEnveloppeDepuisAllocations(enveloppeId);
      } else {
        // Créer une nouvelle allocation si elle n'existe pas
        final nouvelleAllocation = {
          'utilisateur_id': userId,
          'enveloppe_id': enveloppeId,
          'mois': premierDuMois.toIso8601String(),
          'solde': estDepense ? -montant : montant,
          'alloue': 0.0,
          'depense': estDepense ? montant : 0.0,
          'compte_source_id': '',
          'collection_compte_source': '',
        };

        await pb
            .collection('allocations_mensuelles')
            .create(body: nouvelleAllocation);
        // Synchroniser l'enveloppe après création
        await synchroniserEnveloppeDepuisAllocations(enveloppeId);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Traitement du rollover au début du mois
  static Future<void> traiterRolloverMensuel() async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) return;

      final maintenant = DateTime.now();
      final premierDuMois = DateTime(maintenant.year, maintenant.month, 1);
      final moisPrecedent = DateTime(maintenant.year, maintenant.month - 1, 1);

      // Récupérer toutes les enveloppes de l'utilisateur
      final enveloppes = await pb.collection('enveloppes').getList(
            filter: 'utilisateur_id = "$userId"',
          );

      for (final enveloppe in enveloppes.items) {
        // Vérifier si une allocation existe déjà pour ce mois
        final allocationsActuelles =
            await pb.collection('allocations_mensuelles').getList(
                  filter:
                      'enveloppe_id = "${enveloppe.id}" && mois = "${premierDuMois.toIso8601String()}" && utilisateur_id = "$userId"',
                );

        if (allocationsActuelles.items.isEmpty) {
          // Chercher l'allocation du mois précédent
          final allocationsPrecedentes =
              await pb.collection('allocations_mensuelles').getList(
                    filter:
                        'enveloppe_id = "${enveloppe.id}" && mois = "${moisPrecedent.toIso8601String()}" && utilisateur_id = "$userId"',
                  );

          if (allocationsPrecedentes.items.isNotEmpty) {
            final allocationPrecedente = allocationsPrecedentes.items.first;
            final donnees = allocationPrecedente.data;

            final soldeDisponible = (donnees['solde'] ?? 0).toDouble() -
                (donnees['depense'] ?? 0).toDouble();

            if (soldeDisponible > 0) {
              // Créer une allocation de rollover
              final allocationRollover = {
                'utilisateur_id': userId,
                'enveloppe_id': enveloppe.id,
                'mois': premierDuMois.toIso8601String(),
                'solde': soldeDisponible,
                'alloue': 0.0, // Rollover n'est pas une nouvelle allocation
                'depense': 0.0,
                'compte_source_id': '',
                'collection_compte_source': '',
              };

              await pb
                  .collection('allocations_mensuelles')
                  .create(body: allocationRollover);
            }
          }
        }
      }
    } catch (e) {
      // Gestion silencieuse des erreurs
    }
  }

  // Récupérer les allocations mensuelles d'une enveloppe
  static Future<List<AllocationMensuelle>> lireAllocationsMensuelles({
    required String enveloppeId,
    required DateTime mois,
  }) async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;

      if (userId == null) return [];

      final premierDuMois = DateTime(mois.year, mois.month, 1);

      final allocations = await pb
          .collection('allocations_mensuelles')
          .getList(
            filter:
                'enveloppe_id = "$enveloppeId" && mois = "${premierDuMois.toIso8601String()}" && utilisateur_id = "$userId"',
          )
          .timeout(const Duration(seconds: 5));

      return allocations.items
          .map((record) => AllocationMensuelle.fromMap(record.data))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Récupérer les informations du compte source pour une enveloppe et un mois donné
  static Future<Map<String, String?>> obtenirCompteSourceEnveloppe({
    required String enveloppeId,
    required DateTime mois,
  }) async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;
      if (userId == null) {
        return {'compte_source_id': null, 'collection_compte_source': null};
      }

      // Premiere tentative : sans filtre de date, juste enveloppe et utilisateur
      var allocations = await pb.collection('allocations_mensuelles').getList(
            filter:
                'enveloppe_id = "$enveloppeId" && utilisateur_id = "$userId"',
          );

      // Si on trouve des allocations, filtrer par mois en code
      List<dynamic> allocationsFinales = [];
      if (allocations.items.isNotEmpty) {
        allocationsFinales = allocations.items.where((allocation) {
          final moisAllocation = allocation.data['mois']?.toString();
          if (moisAllocation == null) return false;

          // Essayer de parser la date et comparer le mois/annee
          try {
            final dateMois = DateTime.parse(moisAllocation);
            return dateMois.year == mois.year && dateMois.month == mois.month;
          } catch (e) {
            return false;
          }
        }).toList();
      }

      for (final allocation in allocationsFinales) {
        final compteSourceId = allocation.data['compte_source_id']?.toString();
        final collectionCompteSource =
            allocation.data['collection_compte_source']?.toString();

        if (compteSourceId != null &&
            compteSourceId.isNotEmpty &&
            collectionCompteSource != null &&
            collectionCompteSource.isNotEmpty) {
          return {
            'compte_source_id': compteSourceId,
            'collection_compte_source': collectionCompteSource,
          };
        }
      }

      return {'compte_source_id': null, 'collection_compte_source': null};
    } catch (e) {
      return {'compte_source_id': null, 'collection_compte_source': null};
    }
  }

  // Calculer le solde actuel d'une enveloppe pour un mois donné
  // Retourne null si aucune allocation n'existe pour ce mois
  static Future<double?> calculerSoldeEnveloppe({
    required String enveloppeId,
    required DateTime mois,
  }) async {
    try {
      final now = DateTime.now();

      // Si le mois est dans le futur, retourner null (pas de solde à afficher)
      if (mois.isAfter(DateTime(now.year, now.month + 1, 1))) {
        return null;
      }

      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;
      if (userId == null) {
        return null;
      }

      final premierDuMois = DateTime(mois.year, mois.month, 1);
      final dateFiltre = premierDuMois.toIso8601String();

      // Essayer plusieurs formats de filtre pour s'assurer de trouver les allocations
      final filtre1 =
          'enveloppe_id = "$enveloppeId" && mois = "$dateFiltre" && utilisateur_id = "$userId"';
      final filtre2 =
          'enveloppe_id = "$enveloppeId" && utilisateur_id = "$userId"';

      // Essayer avec le premier filtre (date exacte)
      var allocations = await pb.collection('allocations_mensuelles').getList(
            filter: filtre1,
          );

      // Si aucune allocation trouvée avec le premier filtre, essayer avec le second (sans filtre de date)
      if (allocations.items.isEmpty) {
        allocations = await pb.collection('allocations_mensuelles').getList(
              filter: filtre2,
            );

        // Filtrer manuellement par mois
        final allocationsFiltrees = allocations.items.where((alloc) {
          try {
            final dateAlloc = DateTime.parse(alloc.data['mois']);
            return dateAlloc.year == mois.year && dateAlloc.month == mois.month;
          } catch (e) {
            return false;
          }
        }).toList();

        // Si on a trouvé des allocations avec le filtre manuel, les utiliser
        if (allocationsFiltrees.isNotEmpty) {
          allocations.items = allocationsFiltrees;
        }
      }

      // Si aucune allocation trouvée pour ce mois, retourner null
      if (allocations.items.isEmpty) {
        return null;
      }

      // Calculer le solde total des allocations trouvées
      double soldeTotal = 0.0;
      for (final allocation in allocations.items) {
        final solde = (allocation.data['solde'] ?? 0).toDouble();
        soldeTotal += solde;
      }

      return soldeTotal;
    } catch (e) {
      return null;
    }
  }

  /// Synchronise le solde et le compte source principal dans la collection enveloppes
  static Future<void> synchroniserEnveloppeDepuisAllocations(String enveloppeId,
      {DateTime? mois}) async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;
      if (userId == null) return;
      final now = DateTime.now();
      final moisCible = mois ?? DateTime(now.year, now.month, 1);

      // 1. Lire toutes les allocations du mois pour cette enveloppe
      final allocations = await pb.collection('allocations_mensuelles').getList(
            filter:
                'enveloppe_id = "$enveloppeId" && utilisateur_id = "$userId"',
          );
      final allocationsMois = allocations.items.where((alloc) {
        try {
          final dateAlloc = DateTime.parse(alloc.data['mois']);
          return dateAlloc.year == moisCible.year &&
              dateAlloc.month == moisCible.month;
        } catch (_) {
          return false;
        }
      }).toList();

      // 2. Calculer le solde total
      double soldeTotal = 0.0;
      for (final alloc in allocationsMois) {
        soldeTotal += (alloc.data['solde'] ?? 0).toDouble();
      }

      // 3. Prendre le compte source principal (première allocation du mois qui a un compte source)
      String? compteSourceId;
      String? collectionCompteSource;
      RecordModel? allocAvecSource;
      try {
        allocAvecSource = allocationsMois.firstWhere(
          (a) =>
              (a.data['compte_source_id']?.toString() ?? '').isNotEmpty &&
              (a.data['collection_compte_source']?.toString() ?? '').isNotEmpty,
        );
      } catch (_) {
        allocAvecSource =
            allocationsMois.isNotEmpty ? allocationsMois.first : null;
      }
      if (allocAvecSource != null) {
        compteSourceId = allocAvecSource.data['compte_source_id']?.toString();
        collectionCompteSource =
            allocAvecSource.data['collection_compte_source']?.toString();
      }

      // 4. Mettre à jour l'enveloppe
      try {
        final resp =
            await pb.collection('enveloppes').update(enveloppeId, body: {
          'solde_enveloppe': soldeTotal,
          'compte_provenance_id': compteSourceId, // Correction ici
          'collection_compte_source': collectionCompteSource,
        });
      } catch (e) {
        // Gestion silencieuse des erreurs
      }
    } catch (e) {
      // Gestion silencieuse des erreurs
    }
  }

  /// Synchronise toutes les enveloppes de l'utilisateur avec les données d'allocations_mensuelles pour le mois courant
  static Future<void> synchroniserToutesLesEnveloppesUtilisateur(
      {DateTime? mois}) async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;
      if (userId == null) return;
      final now = DateTime.now();
      final moisCible = mois ?? DateTime(now.year, now.month, 1);

      // 1. Récupérer toutes les enveloppes de l'utilisateur
      final enveloppes = await pb.collection('enveloppes').getFullList(
            filter: 'utilisateur_id = "$userId"',
          );
      for (final env in enveloppes) {
        await synchroniserEnveloppeDepuisAllocations(env.id, mois: moisCible);
      }
    } catch (e) {
      // Gestion silencieuse des erreurs
    }
  }
}

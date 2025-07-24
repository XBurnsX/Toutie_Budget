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

        print('✅ Allocation mensuelle mise à jour: ${allocation.id}');
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
        print('✅ Nouvelle allocation mensuelle créée');
      }
    } catch (e) {
      print('❌ Erreur création allocation mensuelle: $e');
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

        print('✅ Allocation mise à jour pour transaction: ${allocation.id}');
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
        print('✅ Nouvelle allocation créée pour transaction');
      }
    } catch (e) {
      print('❌ Erreur mise à jour allocation pour transaction: $e');
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
              print('✅ Rollover créé pour enveloppe: ${enveloppe.id}');
            }
          }
        }
      }
    } catch (e) {
      print('❌ Erreur traitement rollover: $e');
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
      print('❌ Erreur lecture allocations mensuelles: $e');
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
        print('🔍 COMPTE_SOURCE: userId null');
        return {'compte_source_id': null, 'collection_compte_source': null};
      }

      // Essayer plusieurs formats de filtre pour trouver le bon
      print('🔍 COMPTE_SOURCE: Recherche pour enveloppe $enveloppeId');
      
      // Premiere tentative : sans filtre de date, juste enveloppe et utilisateur
      var allocations = await pb.collection('allocations_mensuelles').getList(
            filter: 'enveloppe_id = "$enveloppeId" && utilisateur_id = "$userId"',
          );
      
      print('🔍 COMPTE_SOURCE: ${allocations.items.length} allocations trouvees sans filtre de date');
      
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
            print('🔍 COMPTE_SOURCE: Erreur parsing date: $moisAllocation');
            return false;
          }
        }).toList();
        
        print('🔍 COMPTE_SOURCE: ${allocationsFinales.length} allocations apres filtrage par mois');
      }
      
      print('🔍 COMPTE_SOURCE: ${allocationsFinales.length} allocations finales a traiter');

      // Afficher les allocations filtrées
      for (int i = 0; i < allocationsFinales.length; i++) {
        final allocation = allocationsFinales[i];
        print('🔍 COMPTE_SOURCE: Allocation $i: ID=${allocation.id}');
        print('🔍 COMPTE_SOURCE: - enveloppe_id: ${allocation.data['enveloppe_id']}');
        print('🔍 COMPTE_SOURCE: - mois: ${allocation.data['mois']}');
        print('🔍 COMPTE_SOURCE: - solde: ${allocation.data['solde']}');
        print('🔍 COMPTE_SOURCE: - compte_source_id: ${allocation.data['compte_source_id']}');
        print('🔍 COMPTE_SOURCE: - collection_compte_source: ${allocation.data['collection_compte_source']}');
      }

      for (final allocation in allocationsFinales) {
        final compteSourceId = allocation.data['compte_source_id']?.toString();
        final collectionCompteSource = allocation.data['collection_compte_source']?.toString();
        
        if (compteSourceId != null && compteSourceId.isNotEmpty &&
            collectionCompteSource != null && collectionCompteSource.isNotEmpty) {
          print('🔍 COMPTE_SOURCE: Compte source trouvé: $compteSourceId ($collectionCompteSource)');
          return {
            'compte_source_id': compteSourceId,
            'collection_compte_source': collectionCompteSource,
          };
        }
      }

      print('🔍 COMPTE_SOURCE: Aucun compte source valide trouvé');
      return {'compte_source_id': null, 'collection_compte_source': null};
    } catch (e) {
      print('🔍 COMPTE_SOURCE: Erreur: $e');
      return {'compte_source_id': null, 'collection_compte_source': null};
    }
  }

  // Calculer le solde actuel d'une enveloppe pour un mois donné
  static Future<double> calculerSoldeEnveloppe({
    required String enveloppeId,
    required DateTime mois,
  }) async {
    try {
      final pb = await _getPocketBaseInstance();
      final userId = pb.authStore.model?.id;
      final premierDuMois = DateTime(mois.year, mois.month, 1);

      final filtre =
          'enveloppe_id = "$enveloppeId" && mois = "${premierDuMois.toIso8601String()}" && utilisateur_id = "$userId"';

      final allocations = await pb.collection('allocations_mensuelles').getList(
            filter: filtre,
          );

      double soldeTotal = 0.0;

      for (final allocation in allocations.items) {
        final solde = (allocation.data['solde'] ?? 0).toDouble();
        soldeTotal += solde;
      }

      // Si aucune allocation trouvée avec le filtre, utiliser les allocations utilisateur
      if (allocations.items.isEmpty) {
        final allocationsUtilisateur =
            await pb.collection('allocations_mensuelles').getList(
                  filter: 'utilisateur_id = "$userId"',
                );
        for (final allocation in allocationsUtilisateur.items) {
          if (allocation.data['enveloppe_id'] == enveloppeId) {
            final solde = (allocation.data['solde'] ?? 0).toDouble();
            soldeTotal += solde;
          }
        }
      }

      return soldeTotal;
    } catch (e) {
      return 0.0;
    }
  }
}

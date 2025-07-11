import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/categorie.dart';
import '../models/compte.dart';
import 'firebase_service.dart';

class TransactionImport {
  final String? date;
  final String? montant;
  final String? outflow; // Pour YNAB (dépenses)
  final String? inflow; // Pour YNAB (revenus)
  final String? type; // 'depense' ou 'revenu'
  final String? tiers;
  final String? compte;
  final String? enveloppe;
  final String? categorie;
  final String? note;
  final String? marqueur;

  TransactionImport({
    this.date,
    this.montant,
    this.outflow,
    this.inflow,
    this.type,
    this.tiers,
    this.compte,
    this.enveloppe,
    this.categorie,
    this.note,
    this.marqueur,
  });
}

class ImportCsvService {
  final FirebaseService _firebaseService = FirebaseService();

  // Formats de date supportés
  final List<DateFormat> _formatsDate = [
    DateFormat('dd/MM/yyyy'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('yyyy-MM-dd'),
    DateFormat('dd-MM-yyyy'),
    DateFormat('yyyy/MM/dd'),
    DateFormat('dd/MM/yy'),
    DateFormat('MM/dd/yy'),
  ];

  /// Parse un fichier CSV et retourne les données brutes avec gestion multi-encodage
  Future<List<List<String>>> lireFichierCsv(String filePath) async {
    final file = File(filePath);

    // Liste des encodages à essayer (ordre d'importance)
    final encodages = [
      utf8, // UTF-8 (standard moderne)
      latin1, // ISO-8859-1 / Windows-1252 (très commun)
      ascii, // ASCII (fallback)
    ];

    String? contents;

    // Essayer chaque encodage
    for (var encodage in encodages) {
      try {
        final bytes = await file.readAsBytes();
        contents = encodage.decode(bytes);

        // Validation basique : le contenu doit contenir des caractères CSV valides
        if (contents.contains(',') ||
            contents.contains(';') ||
            contents.contains('\t')) {
          break; // Encodage réussi
        }
      } catch (e) {
        // Essayer l'encodage suivant
        continue;
      }
    }

    if (contents == null) {
      throw Exception(
        'Impossible de lire le fichier avec les encodages supportés (UTF-8, Latin-1, ASCII)',
      );
    }

    try {
      // Détection automatique du délimiteur
      final delimiteur = _detecterDelimiteur(contents);

      final csvConverter = CsvToListConverter(
        fieldDelimiter: delimiteur,
        shouldParseNumbers: false, // On garde tout en String pour la validation
      );

      return csvConverter
          .convert(contents)
          .map((row) => row.map((cell) => cell.toString().trim()).toList())
          .toList();
    } catch (e) {
      throw Exception('Erreur lors du parsing CSV: $e');
    }
  }

  /// Détecte automatiquement le délimiteur CSV
  String _detecterDelimiteur(String content) {
    final delimiteurs = [',', ';', '\t'];
    int maxOccurrences = 0;
    String meilleurDelimiteur = ',';

    for (String delimiteur in delimiteurs) {
      int occurrences = delimiteur.allMatches(content.split('\n').first).length;
      if (occurrences > maxOccurrences) {
        maxOccurrences = occurrences;
        meilleurDelimiteur = delimiteur;
      }
    }

    return meilleurDelimiteur;
  }

  /// Convertit les données CSV en objets TransactionImport basé sur le mapping
  List<TransactionImport> mapperDonneesCsv(
    List<List<String>> donneesCsv,
    Map<String, int> mapping, // colonne -> index
    bool premiereLigneEntetes,
  ) {
    final transactions = <TransactionImport>[];
    final startIndex = premiereLigneEntetes ? 1 : 0;

    for (int i = startIndex; i < donneesCsv.length; i++) {
      final row = donneesCsv[i];
      if (row.isEmpty || row.every((cell) => cell.trim().isEmpty)) continue;

      transactions.add(
        TransactionImport(
          date: _extraireValeur(row, mapping['date']),
          montant: _extraireValeur(row, mapping['montant']),
          outflow: _extraireValeur(row, mapping['outflow']),
          inflow: _extraireValeur(row, mapping['inflow']),
          type: _extraireValeur(row, mapping['type']),
          tiers: _extraireValeur(row, mapping['tiers']),
          compte: _extraireValeur(row, mapping['compte']),
          enveloppe: _extraireValeur(row, mapping['enveloppe']),
          categorie: _extraireValeur(row, mapping['categorie']),
          note: _extraireValeur(row, mapping['note']),
          marqueur: _extraireValeur(row, mapping['marqueur']),
        ),
      );
    }

    return transactions;
  }

  String? _extraireValeur(List<String> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return null;
    final value = row[index].trim();
    return value.isEmpty ? null : value;
  }

  /// Valide et transforme les transactions importées
  Future<List<Transaction>> validerEtTransformerTransactions(
    List<TransactionImport> transactionsImport,
    Function(String message) onError,
    Function(double progress) onProgress,
  ) async {
    final transactions = <Transaction>[];
    final comptes = await _obtenirComptes();
    final categories = await _obtenirCategories();

    // Créer un mapping des noms vers les IDs
    final comptesParNom = <String, String>{};
    for (var compte in comptes) {
      comptesParNom[compte.nom.toLowerCase()] = compte.id;
    }

    final enveloppesParNom = <String, String>{};
    for (var categorie in categories) {
      for (var enveloppe in categorie.enveloppes) {
        enveloppesParNom[enveloppe.nom.toLowerCase()] = enveloppe.id;
      }
    }

    for (int i = 0; i < transactionsImport.length; i++) {
      final transactionImport = transactionsImport[i];

      try {
        // Validation et transformation
        final date = _parserDate(transactionImport.date);
        final montantEtType = _parserMontantYnab(transactionImport);
        final montant = montantEtType['montant'] as double;
        final type = montantEtType['type'] as TypeTransaction;
        final compteId = _trouverCompteId(
          transactionImport.compte,
          comptesParNom,
        );

        // Gestion de l'enveloppe (ignorer "Ready to Assign" qui est du revenus normal YNAB)
        String? enveloppeId;
        if (transactionImport.enveloppe != null &&
            transactionImport.enveloppe!.isNotEmpty &&
            transactionImport.enveloppe!.toLowerCase() != 'ready to assign') {
          enveloppeId = await _obtenirOuCreerEnveloppe(
            transactionImport.enveloppe!,
            transactionImport.categorie ?? 'Non classé',
            enveloppesParNom,
            compteId,
          );
        }

        // Corriger le problème d'affichage -0.00$
        final montantCorrige = montant.abs() == 0.0 ? 0.0 : montant.abs();

        final transaction = Transaction(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          type: type,
          typeMouvement: type == TypeTransaction.depense
              ? TypeMouvementFinancier.depenseNormale
              : TypeMouvementFinancier.revenuNormal,
          montant: montantCorrige, // Évite -0.00$
          compteId: compteId,
          date: date,
          tiers: transactionImport.tiers,
          enveloppeId: enveloppeId,
          note: transactionImport.note,
          marqueur: transactionImport.marqueur,
        );

        transactions.add(transaction);
      } catch (e) {
        onError('Ligne ${i + 1}: $e');
      }

      // Mise à jour du progrès
      onProgress(
        (i + 1) / transactionsImport.length * 0.8,
      ); // 80% pour la validation
    }

    return transactions;
  }

  DateTime _parserDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      throw Exception('Date manquante');
    }

    for (var format in _formatsDate) {
      try {
        return format.parse(dateStr);
      } catch (e) {
        // Continue avec le format suivant
      }
    }

    throw Exception('Format de date non reconnu: $dateStr');
  }

  /// Parse montant YNAB avec support Outflow/Inflow
  Map<String, dynamic> _parserMontantYnab(TransactionImport transaction) {
    double montant = 0.0;
    TypeTransaction type;

    // Vérifier d'abord si c'est du format YNAB (Outflow/Inflow)
    // IMPORTANT: Vérifier que le montant est > 0, pas seulement non-vide
    if (transaction.outflow != null && transaction.outflow!.isNotEmpty) {
      final montantOutflow = _parserMontantSimple(transaction.outflow!);
      if (montantOutflow > 0) {
        montant = montantOutflow;
        type = TypeTransaction.depense;
      } else if (transaction.inflow != null && transaction.inflow!.isNotEmpty) {
        // Si Outflow = 0, vérifier Inflow
        montant = _parserMontantSimple(transaction.inflow!);
        type = TypeTransaction.revenu;
      } else {
        throw Exception('Aucun montant valide trouvé');
      }
    } else if (transaction.inflow != null && transaction.inflow!.isNotEmpty) {
      montant = _parserMontantSimple(transaction.inflow!);
      type = TypeTransaction.revenu;
    } else if (transaction.montant != null && transaction.montant!.isNotEmpty) {
      // Format standard avec montant unique
      montant = _parserMontantSimple(transaction.montant!);
      type = _parserType(transaction.type, montant);
    } else {
      throw Exception('Aucun montant trouvé');
    }

    return {'montant': montant, 'type': type};
  }

  double _parserMontantSimple(String montantStr) {
    if (montantStr.isEmpty) {
      throw Exception('Montant manquant');
    }

    // Nettoyer le montant (enlever espaces, symboles monétaires, $, €)
    String montantCleaned = montantStr
        .replaceAll(
          RegExp(r'[^\d,.-]'),
          '',
        ) // Garde uniquement chiffres, virgules, points, tirets
        .replaceAll(',', '.'); // Convertir virgules en points

    final montant = double.tryParse(montantCleaned);
    if (montant == null) {
      throw Exception('Montant invalide: $montantStr');
    }

    return montant;
  }

  TypeTransaction _parserType(String? typeStr, double montant) {
    if (typeStr != null && typeStr.isNotEmpty) {
      final type = typeStr.toLowerCase();
      if (type.contains('depense') ||
          type.contains('débit') ||
          type.contains('sortie')) {
        return TypeTransaction.depense;
      } else if (type.contains('revenu') ||
          type.contains('crédit') ||
          type.contains('entrée')) {
        return TypeTransaction.revenu;
      }
    }

    // Si pas de type explicite, déduire du montant
    return montant < 0 ? TypeTransaction.depense : TypeTransaction.revenu;
  }

  String _trouverCompteId(
    String? compteNom,
    Map<String, String> comptesParNom,
  ) {
    if (compteNom == null || compteNom.isEmpty) {
      throw Exception('Nom de compte manquant');
    }

    final compteId = comptesParNom[compteNom.toLowerCase()];
    if (compteId == null) {
      throw Exception('Compte non trouvé: $compteNom');
    }

    return compteId;
  }

  Future<String?> _obtenirOuCreerEnveloppe(
    String nomEnveloppe,
    String nomCategorie,
    Map<String, String> enveloppesParNom,
    String compteId,
  ) async {
    // Chercher l'enveloppe existante
    final enveloppeId = enveloppesParNom[nomEnveloppe.toLowerCase()];
    if (enveloppeId != null) {
      return enveloppeId;
    }

    // Créer une nouvelle enveloppe dans la catégorie spécifiée
    final categorie = await _obtenirOuCreerCategorie(nomCategorie);
    final nouvelleEnveloppe = Enveloppe(
      id: '${DateTime.now().millisecondsSinceEpoch}_env',
      nom: nomEnveloppe,
      provenanceCompteId: compteId,
    );

    // Ajouter l'enveloppe à la catégorie
    final categorieModifiee = Categorie(
      id: categorie.id,
      userId: categorie.userId,
      nom: categorie.nom,
      enveloppes: [...categorie.enveloppes, nouvelleEnveloppe],
    );

    await _firebaseService.ajouterCategorie(categorieModifiee);

    // Mettre à jour le cache local
    enveloppesParNom[nomEnveloppe.toLowerCase()] = nouvelleEnveloppe.id;

    return nouvelleEnveloppe.id;
  }

  Future<Categorie> _obtenirOuCreerCategorie(String nomCategorie) async {
    final categories = await _obtenirCategories();

    // Chercher la catégorie existante
    final categorieExistante = categories.firstWhere(
      (cat) => cat.nom.toLowerCase() == nomCategorie.toLowerCase(),
      orElse: () => Categorie(id: '', nom: '', enveloppes: []),
    );

    if (categorieExistante.id.isNotEmpty) {
      return categorieExistante;
    }

    // Créer la nouvelle catégorie
    final nouvelleCategorie = Categorie(
      id: '${DateTime.now().millisecondsSinceEpoch}_cat',
      nom: nomCategorie,
      enveloppes: [],
    );

    await _firebaseService.ajouterCategorie(nouvelleCategorie);
    return nouvelleCategorie;
  }

  /// Génère une signature unique pour détecter les doublons (tiers|date|montant)
  String _signatureTransaction(Transaction t) {
    final tiers = (t.tiers ?? '').toLowerCase().trim();
    final dateIso = t.date.toIso8601String(); // ISO complet pour unicité
    final montant = t.montant.toStringAsFixed(2);
    return '$tiers|$dateIso|$montant';
  }

  /// Charge toutes les transactions existantes de l'utilisateur et renvoie les signatures
  Future<Set<String>> _chargerSignaturesExistantes() async {
    final userId = _firebaseService.auth.currentUser?.uid;
    if (userId == null) return {};

    final snapshot = await _firebaseService.firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .get();

    final signatures = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final tiers = (data['tiers'] ?? '').toString().toLowerCase().trim();
      final dateStr = data['date'] as String?; // Stocké ISO
      final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;
      if (dateStr != null) {
        final signature = '$tiers|$dateStr|${montant.toStringAsFixed(2)}';
        signatures.add(signature);
      }
    }
    return signatures;
  }

  /// Importe les transactions en traitant mois par mois avec remise à zéro intelligente
  Future<void> importerTransactions(
    List<Transaction> transactions,
    Function(double progress) onProgress,
  ) async {
    if (transactions.isEmpty) {
      return;
    }

    // ----- Nouveauté : déduplication -----
    final signaturesExistantes = await _chargerSignaturesExistantes();
    final transactionsFiltrees = <Transaction>[];
    final signaturesAjoutees =
        <String>{}; // éviter doublons à l'intérieur du CSV

    for (var t in transactions) {
      final sig = _signatureTransaction(t);
      if (signaturesExistantes.contains(sig) ||
          signaturesAjoutees.contains(sig)) {
        // Déjà présent, on ignore
        continue;
      }
      transactionsFiltrees.add(t);
      signaturesAjoutees.add(sig);
    }

    if (transactionsFiltrees.isEmpty) {
      onProgress(1.0);
      return; // Rien à importer après déduplication
    }

    // On remplace la variable d'entrée par la liste filtrée
    transactions = transactionsFiltrees;

    // Étape 1 : Grouper les transactions par mois
    final transactionsParMois = <String, List<Transaction>>{};
    for (var transaction in transactions) {
      final cleeMois =
          '${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}';
      transactionsParMois.putIfAbsent(cleeMois, () => []).add(transaction);
    }

    // Étape 2 : Trier les mois par ordre chronologique
    final moisOrdonnes = transactionsParMois.keys.toList()..sort();

    // Étape 3 : Remise à zéro UNIQUE au début
    await _remettreAZeroEtTransfererVersPretAPlacer(
      'DEBUT_IMPORT',
      (subProgress) => onProgress(subProgress * 0.1), // 0-10%
    );

    // Étape 4 : Traiter chaque mois séquentiellement avec la logique correcte
    int totalMois = moisOrdonnes.length;

    for (int i = 0; i < moisOrdonnes.length; i++) {
      final mois = moisOrdonnes[i];
      final transactionsDuMois = transactionsParMois[mois]!;

      await _traiterMoisAvecCompensation(mois, transactionsDuMois);

      // La compensation des enveloppes négatives est maintenant effectuée
      // à l'intérieur de _traiterMoisAvecCompensation après les dépenses.

      onProgress(0.1 + ((i + 1) / totalMois) * 0.8); // 10-90%
    }

    // Étape 5 : Remise à zéro finale des enveloppes (comme demandé)
    await _remettreAZeroEtTransfererVersPretAPlacer(
      'FIN_IMPORT',
      (subProgress) => onProgress(0.9 + subProgress * 0.05), // 90-95%
    );

    // Étape 6 : Recalibrage final du prêt à placer pour cohérence
    await _recalibrerPretAPlacer();
    onProgress(1.0); // 100%
  }

  /// Remet à zéro les enveloppes et transfère l'argent vers le prêt à placer
  Future<void> _remettreAZeroEtTransfererVersPretAPlacer(
    String mois,
    Function(double progress) onProgress,
  ) async {
    final categories = await _obtenirCategories();
    final comptes = await _obtenirComptes();
    final comptesParId = {for (var compte in comptes) compte.id: compte};

    int totalEnveloppes = 0;
    int enveloppesTraitees = 0;

    // Compter le total d'enveloppes
    for (var categorie in categories) {
      totalEnveloppes += categorie.enveloppes.length;
    }

    if (totalEnveloppes == 0) {
      onProgress(1.0);
      return;
    }

    // Traiter chaque catégorie
    for (var categorie in categories) {
      bool categorieModifiee = false;
      final enveloppesModifiees = <Enveloppe>[];

      for (var enveloppe in categorie.enveloppes) {
        if (enveloppe.solde > 0.0) {
          // Transférer l'argent vers le prêt à placer du compte correspondant
          final compte = comptesParId[enveloppe.provenanceCompteId];
          if (compte != null) {
            final nouveauPretAPlacer = compte.pretAPlacer + enveloppe.solde;
            final compteModifie = Compte(
              id: compte.id,
              userId: compte.userId,
              nom: compte.nom,
              type: compte.type,
              solde: compte.solde,
              couleur: compte.couleur,
              pretAPlacer: nouveauPretAPlacer,
              dateCreation: compte.dateCreation,
              estArchive: compte.estArchive,
              dateSuppression: compte.dateSuppression,
            );

            // Sauvegarder le compte modifié
            await _firebaseService.ajouterCompte(compteModifie);
          }

          // Remettre l'enveloppe à zéro
          enveloppesModifiees.add(
            Enveloppe(
              id: enveloppe.id,
              nom: enveloppe.nom,
              solde: 0.0,
              provenanceCompteId: enveloppe.provenanceCompteId,
            ),
          );
          categorieModifiee = true;
        } else {
          enveloppesModifiees.add(enveloppe); // Pas de changement
        }

        enveloppesTraitees++;
        onProgress(enveloppesTraitees / totalEnveloppes);
      }

      // Sauvegarder la catégorie modifiée
      if (categorieModifiee) {
        final categorieAvecNouveauxSoldes = Categorie(
          id: categorie.id,
          userId: categorie.userId,
          nom: categorie.nom,
          enveloppes: enveloppesModifiees,
        );

        await _firebaseService.ajouterCategorie(categorieAvecNouveauxSoldes);
      }
    }
  }

  /// Traite un mois avec compensation intelligente selon la logique :
  /// 1. Créer les enveloppes manquantes
  /// 2. Ajouter les DÉPENSES (enveloppes négatives + baisse du solde compte)
  /// 3. Compenser avec le prêt à placer (remettre enveloppes à 0)
  /// 4. Ajouter les REVENUS (augmenter solde compte + prêt à placer)
  Future<void> _traiterMoisAvecCompensation(
    String mois,
    List<Transaction> transactionsDuMois,
  ) async {
    // Séparer revenus et dépenses
    final revenus = transactionsDuMois
        .where((t) => t.type == TypeTransaction.revenu)
        .toList();
    final depenses = transactionsDuMois
        .where((t) => t.type == TypeTransaction.depense)
        .toList();

    // Étape 1 : Créer les enveloppes manquantes pour les dépenses
    await _creerEnveloppesManquantes(depenses);

    // Étape 2 : Ajouter toutes les DÉPENSES
    // Cela va mettre les enveloppes en négatif et baisser le solde du compte
    for (var depense in depenses) {
      await _firebaseService.ajouterTransaction(depense);
    }

    // Étape 3 : Compense immédiatement les enveloppes négatives
    // en utilisant le prêt à placer du compte correspondant
    await _compenserEnveloppesNegatives();

    // Étape 4 : Ajouter tous les REVENUS
    // Cela va augmenter le solde du compte et le prêt à placer
    for (var revenu in revenus) {
      await _firebaseService.ajouterTransaction(revenu);
    }

    // Note : plus besoin de compensation ici, elle a été faite avant les revenus
  }

  /// Crée les enveloppes manquantes pour les dépenses
  Future<void> _creerEnveloppesManquantes(List<Transaction> depenses) async {
    final categories = await _obtenirCategories();
    final enveloppesExistantes = <String>{};

    // Recenser toutes les enveloppes existantes
    for (var categorie in categories) {
      for (var enveloppe in categorie.enveloppes) {
        enveloppesExistantes.add(enveloppe.id);
      }
    }

    // Créer les enveloppes manquantes
    for (var depense in depenses) {
      if (depense.enveloppeId != null &&
          !enveloppesExistantes.contains(depense.enveloppeId)) {
        // L'enveloppe n'existe pas, on doit la créer
        // Pour l'instant, on crée une enveloppe générique
        await _creerEnveloppeGenerique(depense.enveloppeId!, depense.compteId);
        enveloppesExistantes.add(depense.enveloppeId!);
      }
    }
  }

  /// Crée une enveloppe générique pour l'import
  Future<void> _creerEnveloppeGenerique(
    String enveloppeId,
    String compteId,
  ) async {
    final categories = await _obtenirCategories();

    // Chercher une catégorie "Import" ou créer une nouvelle
    Categorie? categorieImport;
    for (var categorie in categories) {
      if (categorie.nom.toLowerCase() == 'import' ||
          categorie.nom.toLowerCase() == 'importé') {
        categorieImport = categorie;
        break;
      }
    }

    if (categorieImport == null) {
      // Créer la catégorie "Import"
      categorieImport = Categorie(
        id: '${DateTime.now().millisecondsSinceEpoch}_import',
        nom: 'Import',
        enveloppes: [],
      );
      await _firebaseService.ajouterCategorie(categorieImport);
    }

    // Ajouter l'enveloppe à la catégorie
    final nouvelleEnveloppe = Enveloppe(
      id: enveloppeId,
      nom: 'Enveloppe $enveloppeId',
      provenanceCompteId: compteId,
      solde: 0.0,
    );

    final categorieModifiee = Categorie(
      id: categorieImport.id,
      userId: categorieImport.userId,
      nom: categorieImport.nom,
      enveloppes: [...categorieImport.enveloppes, nouvelleEnveloppe],
    );

    await _firebaseService.ajouterCategorie(categorieModifiee);
  }

  /// Compense les enveloppes négatives avec le prêt à placer
  Future<void> _compenserEnveloppesNegatives() async {
    final categories = await _obtenirCategories();
    final comptes = await _obtenirComptes();
    final comptesParId = {for (var compte in comptes) compte.id: compte};

    for (var categorie in categories) {
      bool categorieModifiee = false;
      final enveloppesModifiees = <Enveloppe>[];

      for (var enveloppe in categorie.enveloppes) {
        if (enveloppe.solde < 0) {
          // Enveloppe négative, on compense avec le prêt à placer
          final montantACompenser = -enveloppe.solde; // Montant positif
          final compte = comptesParId[enveloppe.provenanceCompteId];

          if (compte != null) {
            // Diminuer le prêt à placer
            final nouveauPretAPlacer = compte.pretAPlacer - montantACompenser;
            final compteModifie = Compte(
              id: compte.id,
              userId: compte.userId,
              nom: compte.nom,
              type: compte.type,
              solde: compte.solde,
              couleur: compte.couleur,
              pretAPlacer: nouveauPretAPlacer < 0 ? 0 : nouveauPretAPlacer,
              dateCreation: compte.dateCreation,
              estArchive: compte.estArchive,
              dateSuppression: compte.dateSuppression,
            );

            // Sauvegarder le compte modifié
            await _firebaseService.ajouterCompte(compteModifie);
            comptesParId[compte.id] = compteModifie; // Mettre à jour le cache
          }

          // Remettre l'enveloppe à 0
          enveloppesModifiees.add(
            Enveloppe(
              id: enveloppe.id,
              nom: enveloppe.nom,
              solde: 0.0,
              provenanceCompteId: enveloppe.provenanceCompteId,
            ),
          );
          categorieModifiee = true;
        } else {
          enveloppesModifiees.add(enveloppe); // Pas de changement
        }
      }

      // Sauvegarder la catégorie modifiée
      if (categorieModifiee) {
        final categorieAvecNouveauxSoldes = Categorie(
          id: categorie.id,
          userId: categorie.userId,
          nom: categorie.nom,
          enveloppes: enveloppesModifiees,
        );

        await _firebaseService.ajouterCategorie(categorieAvecNouveauxSoldes);
      }
    }
  }

  Future<List<Compte>> _obtenirComptes() async {
    final snapshot = await _firebaseService.firestore
        .collection('comptes')
        .where('userId', isEqualTo: _firebaseService.auth.currentUser?.uid)
        .get();

    return snapshot.docs
        .map((doc) => Compte.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Méthode publique pour obtenir les comptes disponibles (nom -> id)
  Future<Map<String, String>> obtenirComptesDisponibles() async {
    final comptes = await _obtenirComptes();
    final comptesMap = <String, String>{};
    for (var compte in comptes) {
      comptesMap[compte.nom] = compte.id;
    }
    return comptesMap;
  }

  Future<List<Categorie>> _obtenirCategories() async {
    final snapshot = await _firebaseService.firestore
        .collection('categories')
        .where('userId', isEqualTo: _firebaseService.auth.currentUser?.uid)
        .get();

    return snapshot.docs.map((doc) => Categorie.fromMap(doc.data())).toList();
  }

  /// Extrait les comptes uniques du CSV pour validation
  Set<String> extraireComptesUniques(List<TransactionImport> transactions) {
    return transactions
        .where((t) => t.compte != null && t.compte!.isNotEmpty)
        .map((t) => t.compte!)
        .toSet();
  }

  /// Valide le mapping des comptes avant import
  String? validerMappingComptes(
    Set<String> comptesYnab,
    Map<String, String> mappingComptes,
    Map<String, String> comptesDisponibles,
  ) {
    for (String compteYnab in comptesYnab) {
      if (!mappingComptes.containsKey(compteYnab)) {
        return 'Compte YNAB "$compteYnab" non mappé';
      }

      final compteChoisi = mappingComptes[compteYnab];
      if (compteChoisi == null ||
          !comptesDisponibles.containsKey(compteChoisi)) {
        return 'Compte "$compteChoisi" non valide pour "$compteYnab"';
      }
    }
    return null; // Tout est OK
  }

  /// Applique le mapping des comptes aux transactions
  List<TransactionImport> appliquerMappingComptes(
    List<TransactionImport> transactions,
    Map<String, String> mappingComptes,
  ) {
    return transactions.map((transaction) {
      if (transaction.compte != null &&
          mappingComptes.containsKey(transaction.compte)) {
        // Remplacer le nom YNAB par le nom Toutie Budget
        return TransactionImport(
          date: transaction.date,
          montant: transaction.montant,
          outflow: transaction.outflow,
          inflow: transaction.inflow,
          type: transaction.type,
          tiers: transaction.tiers,
          compte: mappingComptes[transaction.compte], // Mapping appliqué
          enveloppe: transaction.enveloppe,
          categorie: transaction.categorie,
          note: transaction.note,
          marqueur: transaction.marqueur,
        );
      }
      return transaction; // Pas de changement
    }).toList();
  }

  /// Recalibre le prêt à placer de chaque compte pour qu'il corresponde au solde disponible non alloué
  Future<void> _recalibrerPretAPlacer() async {
    final comptes = await _obtenirComptes();
    final categories = await _obtenirCategories();

    // Calcul rapide : somme des soldes d'enveloppes par compte
    final enveloppeSoldeParCompte = <String, double>{};
    for (final cat in categories) {
      for (final env in cat.enveloppes) {
        final compteId = env.provenanceCompteId;
        final soldeEnv = env.solde;
        enveloppeSoldeParCompte.update(
          compteId,
          (v) => v + soldeEnv,
          ifAbsent: () => soldeEnv,
        );
      }
    }

    for (final compte in comptes) {
      final totalEnveloppes = enveloppeSoldeParCompte[compte.id] ?? 0.0;
      final pretAPlacerVise = compte.solde - totalEnveloppes;
      double nouveauPret = pretAPlacerVise;
      if (nouveauPret < 0) nouveauPret = 0;
      if ((nouveauPret - compte.pretAPlacer).abs() > 0.01) {
        // Mettre à jour uniquement si différence significative
        final compteCorrige = Compte(
          id: compte.id,
          userId: compte.userId,
          nom: compte.nom,
          type: compte.type,
          solde: compte.solde,
          couleur: compte.couleur,
          pretAPlacer: nouveauPret,
          dateCreation: compte.dateCreation,
          estArchive: compte.estArchive,
          dateSuppression: compte.dateSuppression,
        );
        await _firebaseService.ajouterCompte(compteCorrige);
      }
    }
  }
}

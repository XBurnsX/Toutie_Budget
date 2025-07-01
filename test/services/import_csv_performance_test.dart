import 'package:flutter_test/flutter_test.dart';
import 'dart:math';
import 'dart:io';

void main() {
  group('Test de Performance Import CSV - 1900 Transactions YNAB', () {
    test('Génération de fichier CSV YNAB avec 1900 transactions québécoises', () async {
      print('\n🧪 TEST DE GÉNÉRATION - 1900 TRANSACTIONS YNAB QUÉBÉCOISES');
      print('=' * 70);

      // Générer le fichier CSV avec 1900 transactions
      final stopwatchGeneration = Stopwatch()..start();
      final fichierCsv = await _genererFichierYnab1900Transactions();
      stopwatchGeneration.stop();

      print('✅ Fichier CSV YNAB généré: ${fichierCsv.path}');
      print(
        '⏱️ Temps de génération: ${stopwatchGeneration.elapsedMilliseconds}ms',
      );

      try {
        // Vérifier la taille du fichier
        final tailleBytes = await fichierCsv.length();
        print(
          '📏 Taille du fichier: ${(tailleBytes / 1024).toStringAsFixed(2)} KB',
        );

        // Lire le fichier CSV
        final stopwatchLecture = Stopwatch()..start();
        final contenu = await fichierCsv.readAsString();
        final lignes = contenu
            .split('\n')
            .where((ligne) => ligne.trim().isNotEmpty)
            .toList();
        stopwatchLecture.stop();

        print('📖 Lignes CSV lues: ${lignes.length}');
        print('⏱️ Temps de lecture: ${stopwatchLecture.elapsedMilliseconds}ms');

        // Vérifier la structure YNAB
        expect(lignes.length, equals(1901)); // 1900 transactions + 1 entête
        expect(
          lignes.first,
          equals(
            '"Account","Flag","Date","Payee","Category Group/Category","Category Group","Category","Memo","Outflow","Inflow","Cleared"',
          ),
        );

        // Parser et analyser les données
        final stopwatchParsing = Stopwatch()..start();
        final transactionsParsees = await _parserDonneesYnab(lignes);
        stopwatchParsing.stop();

        print('🔄 Transactions parsées: ${transactionsParsees.length}');
        print('⏱️ Temps de parsing: ${stopwatchParsing.elapsedMilliseconds}ms');

        expect(transactionsParsees.length, equals(1900));

        // Analyser les données générées avec format québécois
        await _analyserDonneesYnab(transactionsParsees);

        // Statistiques de performance
        final tempsTotal =
            stopwatchGeneration.elapsedMilliseconds +
            stopwatchLecture.elapsedMilliseconds +
            stopwatchParsing.elapsedMilliseconds;

        print('\n📊 RÉSULTATS DE PERFORMANCE YNAB:');
        print('=' * 60);
        print('⏱️ Temps total: ${tempsTotal}ms');
        print(
          '📈 Transactions/seconde: ${(1900 / tempsTotal * 1000).toStringAsFixed(2)}',
        );
        print(
          '💾 Vitesse lecture: ${(tailleBytes / stopwatchLecture.elapsedMilliseconds * 1000 / 1024).toStringAsFixed(2)} KB/s',
        );
        print('🏦 Simulation complète de données québécoises/canadiennes');
      } finally {
        // Nettoyer le fichier temporaire
        if (await fichierCsv.exists()) {
          await fichierCsv.delete();
          print('🗑️ Fichier temporaire supprimé');
        }
      }
    });

    test('Test de validation avec format YNAB exact', () async {
      print('\n🔍 TEST DE VALIDATION FORMAT YNAB');
      print('=' * 50);

      final fichierCsv = await _genererFichierYnabValidation();

      try {
        final contenu = await fichierCsv.readAsString();
        final lignes = contenu
            .split('\n')
            .where((ligne) => ligne.trim().isNotEmpty)
            .toList();
        final transactionsParsees = await _parserDonneesYnab(lignes);

        print('📊 Transactions YNAB validées: ${transactionsParsees.length}');

        // Vérifier le format des montants avec $
        var montantAvecDollar = 0;
        var revenus = 0.0;
        var depenses = 0.0;

        for (var transaction in transactionsParsees) {
          if (transaction['outflow']?.contains('\$') == true)
            montantAvecDollar++;
          if (transaction['inflow']?.contains('\$') == true)
            montantAvecDollar++;

          // Calculer totaux (enlever $ et convertir)
          final outflow =
              double.tryParse(
                transaction['outflow']
                        ?.replaceAll('\$', '')
                        .replaceAll(',', '') ??
                    '0',
              ) ??
              0;
          final inflow =
              double.tryParse(
                transaction['inflow']
                        ?.replaceAll('\$', '')
                        .replaceAll(',', '') ??
                    '0',
              ) ??
              0;

          if (inflow > 0) revenus += inflow;
          if (outflow > 0) depenses += outflow;
        }

        print('💰 Format \$ détecté: $montantAvecDollar montants');
        print('📈 Revenus totaux: ${revenus.toStringAsFixed(2)}\$');
        print('📉 Dépenses totales: ${depenses.toStringAsFixed(2)}\$');
        print('✅ Format YNAB québécois validé!');
      } finally {
        if (await fichierCsv.exists()) {
          await fichierCsv.delete();
          print('🗑️ Fichier de validation supprimé');
        }
      }
    });

    test('Test de stress - 5 fichiers de 1900 transactions', () async {
      print('\n🚀 TEST DE STRESS - 5 FICHIERS DE 1900 TRANSACTIONS');
      print('=' * 60);

      final fichiers = <File>[];
      final stopwatch = Stopwatch()..start();

      try {
        // Générer 5 fichiers de 1900 transactions en parallèle
        final futures = List.generate(
          5,
          (index) => _genererFichierYnab1900Transactions(),
        );
        fichiers.addAll(await Future.wait(futures));

        stopwatch.stop();

        print(
          '✅ ${fichiers.length} fichiers YNAB générés en ${stopwatch.elapsedMilliseconds}ms',
        );
        print('📊 Total: ${fichiers.length * 1900} transactions');

        // Vérifier tous les fichiers
        int totalLignes = 0;
        for (var fichier in fichiers) {
          final contenu = await fichier.readAsString();
          final lignes = contenu
              .split('\n')
              .where((ligne) => ligne.trim().isNotEmpty)
              .toList();
          totalLignes += lignes.length - 1; // -1 pour l'entête
        }

        expect(totalLignes, equals(9500)); // 5 * 1900 transactions
        print(
          '📈 Performance: ${(9500 / stopwatch.elapsedMilliseconds * 1000).toStringAsFixed(2)} transactions/sec',
        );
      } finally {
        // Nettoyer tous les fichiers
        for (var fichier in fichiers) {
          if (await fichier.exists()) {
            await fichier.delete();
          }
        }
        print('🗑️ ${fichiers.length} fichiers temporaires supprimés');
      }
    });
  });
}

/// Parse les données CSV YNAB en format Map
Future<List<Map<String, String>>> _parserDonneesYnab(
  List<String> lignes,
) async {
  final transactions = <Map<String, String>>[];

  if (lignes.isEmpty) return transactions;

  // Entêtes YNAB (première ligne)
  final entetesLigne = lignes.first.replaceAll('"', '');
  final entetes = entetesLigne.split(',');

  // Parser chaque ligne de données
  for (int i = 1; i < lignes.length; i++) {
    final ligne = lignes[i];
    if (ligne.trim().isEmpty) continue;

    // Parser CSV avec guillemets
    final valeurs = _parseLineCSV(ligne);

    if (valeurs.length >= entetes.length) {
      final transaction = <String, String>{};
      for (int j = 0; j < entetes.length; j++) {
        final key = entetes[j]
            .toLowerCase()
            .replaceAll('/', '_')
            .replaceAll(' ', '_');
        transaction[key] = j < valeurs.length ? valeurs[j] : '';
      }
      transactions.add(transaction);
    }
  }

  return transactions;
}

/// Parse une ligne CSV avec gestion des guillemets
List<String> _parseLineCSV(String ligne) {
  final resultat = <String>[];
  bool dansGuillemets = false;
  String valeurCourante = '';

  for (int i = 0; i < ligne.length; i++) {
    final char = ligne[i];

    if (char == '"') {
      dansGuillemets = !dansGuillemets;
    } else if (char == ',' && !dansGuillemets) {
      resultat.add(valeurCourante);
      valeurCourante = '';
    } else {
      valeurCourante += char;
    }
  }

  resultat.add(valeurCourante); // Dernière valeur
  return resultat;
}

/// Génère un fichier CSV YNAB avec 1900 transactions québécoises
Future<File> _genererFichierYnab1900Transactions() async {
  final random = Random(42);
  final fichier = File(
    'test_ynab_1900_transactions_${DateTime.now().millisecondsSinceEpoch}.csv',
  );
  final csv = StringBuffer();

  // Entêtes YNAB exactes
  csv.writeln(
    '"Account","Flag","Date","Payee","Category Group/Category","Category Group","Category","Memo","Outflow","Inflow","Cleared"',
  );

  // Données réalistes québécoises/canadiennes
  final comptes = [
    'WealthSimple Cash',
    'Principal',
    'Classique Visa Desjardins',
    '🚨 Fonds d\'urgence',
    'WealthSimple CELI',
    'WealthSimple Crypto',
    'Chomage',
  ];

  final payeesQuebecois = [
    'Paye Arbec',
    'Irving Port-Cartier',
    'Maxi Port Cartier',
    'IGA Port-Cartier',
    'Super C',
    'Bell',
    'Hydro-Québec',
    'SAAQ',
    'Government of Canada',
    'Government of Quebec',
    'McDonald\'s',
    'Tim Hortons',
    'Boni-Soir',
    'Dollarama',
    'Canadian Tire',
    'Shell',
    'Irving',
    'Ultramar',
    'Costco',
    'Metro',
    'Amazon',
    'Microsoft Store',
    'Adobe',
    'Netflix',
    'YouTube Premium',
    'YNAB',
    'Patreon',
    'Steam',
    'Amazon Prime',
    'Apple',
    'Beneva',
    'Desjardins Financial Security',
    'INTACT COMPAGNIE D ASSURANCE',
    'Reçu de Katherine',
    'Money transfer sent to /Katherine',
    'Money transfer sent to /Papa',
    'Interest',
    'WealthSimple interet',
    'Member Dividend',
    'Fixed service charges',
  ];

  final categoriesObligatoires = [
    '🍲 Epicerie',
    '🏠 Loyer',
    '📱 Cellulaire',
    '🚗 Assurance Auto',
    '🏚️ Assurance Maison',
    '🪪 SAAQ',
    '🏦 Frais Desjardins',
    '🖥️ Dell',
    'Tire',
    'Ordi PL',
    'Affirm',
    'Affirm kath',
  ];

  final categoriesNonObligatoires = [
    '⛽ Gaz',
    '🚬 Cigarette',
    '🥃 Redbull',
    '👩‍🍳 Restaurant',
    '🛒 Amazon',
    '🏪 Dépanneur',
  ];

  final abonnements = [
    'Youtube Premium',
    'YNAB',
    'Patreon',
    'Amazon Prime',
    'IPTV',
    'Adobe Creative',
  ];

  final categoriesIrregulieres = [
    'Autre Non Credit',
    ' ❤️ Katherine',
    '🤌 Frais et Interet',
  ];

  // Générer 1900 transactions sur environ 15 mois
  for (int i = 0; i < 1900; i++) {
    // Date réaliste (15 derniers mois)
    final joursEcoules = random.nextInt(450); // ~15 mois
    final date = DateTime.now().subtract(Duration(days: joursEcoules));
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    final compte = comptes[random.nextInt(comptes.length)];
    final payee = payeesQuebecois[random.nextInt(payeesQuebecois.length)];
    final cleared = random.nextBool()
        ? 'Cleared'
        : (random.nextBool() ? 'Reconciled' : 'Uncleared');

    String categoryGroup, category, outflow, inflow, memo;

    // 15% revenus/inflows, 85% dépenses
    if (random.nextInt(100) < 15) {
      // Revenus
      categoryGroup = 'Inflow';
      category = 'Ready to Assign';
      outflow = '0.00\$';

      if (payee.contains('Paye')) {
        inflow =
            '${(random.nextInt(400) + 700)}.${random.nextInt(100).toString().padLeft(2, '0')}\$'; // 700-1100$
      } else if (payee.contains('Interest') || payee.contains('interet')) {
        inflow =
            '${random.nextInt(50) + 1}.${random.nextInt(100).toString().padLeft(2, '0')}\$'; // 1-50$
      } else {
        inflow =
            '${random.nextInt(500) + 50}.${random.nextInt(100).toString().padLeft(2, '0')}\$'; // 50-550$
      }
      memo = '';
    } else {
      // Dépenses
      inflow = '0.00\$';
      memo = '';

      final typeDepense = random.nextInt(100);
      if (typeDepense < 40) {
        // Dépenses obligatoires (40%)
        categoryGroup = 'Dépense Obligatoire';
        category =
            categoriesObligatoires[random.nextInt(
              categoriesObligatoires.length,
            )];

        if (category.contains('Loyer')) {
          outflow = '600.00\$';
        } else if (category.contains('Cellulaire')) {
          outflow = '104.35\$';
        } else if (category.contains('Epicerie')) {
          outflow =
              '${random.nextInt(200) + 20}.${random.nextInt(100).toString().padLeft(2, '0')}\$';
        } else {
          outflow =
              '${random.nextInt(300) + 10}.${random.nextInt(100).toString().padLeft(2, '0')}\$';
        }
      } else if (typeDepense < 70) {
        // Dépenses non obligatoires (30%)
        categoryGroup = 'Dépense Non Obligatoire';
        category =
            categoriesNonObligatoires[random.nextInt(
              categoriesNonObligatoires.length,
            )];

        if (category.contains('Cigarette')) {
          outflow =
              '${random.nextInt(100) + 150}.${random.nextInt(100).toString().padLeft(2, '0')}\$'; // 150-250$
        } else if (category.contains('Gaz')) {
          outflow =
              '${random.nextInt(100) + 80}.${random.nextInt(100).toString().padLeft(2, '0')}\$'; // 80-180$
        } else {
          outflow =
              '${random.nextInt(80) + 10}.${random.nextInt(100).toString().padLeft(2, '0')}\$';
        }
      } else if (typeDepense < 85) {
        // Abonnements (15%)
        categoryGroup = 'Abonnement';
        category = abonnements[random.nextInt(abonnements.length)];
        outflow =
            '${random.nextInt(30) + 5}.${random.nextInt(100).toString().padLeft(2, '0')}\$'; // 5-35$
      } else {
        // Dépenses irrégulières (15%)
        categoryGroup = 'Dépense Irrégulière';
        category =
            categoriesIrregulieres[random.nextInt(
              categoriesIrregulieres.length,
            )];
        outflow =
            '${random.nextInt(200) + 5}.${random.nextInt(100).toString().padLeft(2, '0')}\$';
      }
    }

    final categoryGroupCategory = '$categoryGroup: $category';

    // Ligne CSV YNAB avec guillemets
    csv.writeln(
      '"$compte","","$dateStr","$payee","$categoryGroupCategory","$categoryGroup","$category","$memo",$outflow,$inflow,"$cleared"',
    );
  }

  await fichier.writeAsString(csv.toString());
  return fichier;
}

/// Génère un fichier YNAB plus petit pour validation
Future<File> _genererFichierYnabValidation() async {
  final fichier = File(
    'test_ynab_validation_${DateTime.now().millisecondsSinceEpoch}.csv',
  );
  final csv = StringBuffer();

  csv.writeln(
    '"Account","Flag","Date","Payee","Category Group/Category","Category Group","Category","Memo","Outflow","Inflow","Cleared"',
  );

  // Transactions québécoises réalistes
  final transactions = [
    '"WealthSimple Cash","","19/06/2025","Paye Arbec","Inflow: Ready to Assign","Inflow","Ready to Assign","",0.00\$,1011.88\$,"Cleared"',
    '"WealthSimple Cash","","20/06/2025","Maxi Port Cartier","Dépense Obligatoire: 🍲 Epicerie","Dépense Obligatoire","🍲 Epicerie","",26.03\$,0.00\$,"Cleared"',
    '"WealthSimple Cash","","17/06/2025","Shell","Dépense Non Obligatoire: 🚬 Cigarette","Dépense Non Obligatoire","🚬 Cigarette","",148.62\$,0.00\$,"Cleared"',
    '"WealthSimple Cash","","30/05/2025","Bell","Dépense Obligatoire: 📱 Cellulaire","Dépense Obligatoire","📱 Cellulaire","",104.35\$,0.00\$,"Cleared"',
    '"WealthSimple Cash","","31/05/2025","Paiement Loyer Papa","Dépense Obligatoire: 🏠 Loyer","Dépense Obligatoire","🏠 Loyer","",600.00\$,0.00\$,"Cleared"',
    '"WealthSimple Cash","","10/06/2025","YouTube Premium","Abonnement: Youtube Premium","Abonnement","Youtube Premium","",14.94\$,0.00\$,"Cleared"',
    '"WealthSimple Cash","","01/06/2025","Interest","Inflow: Ready to Assign","Inflow","Ready to Assign","",0.00\$,2.08\$,"Cleared"',
  ];

  for (var transaction in transactions) {
    csv.writeln(transaction);
  }

  await fichier.writeAsString(csv.toString());
  return fichier;
}

/// Analyse les données YNAB générées
Future<void> _analyserDonneesYnab(
  List<Map<String, String>> transactions,
) async {
  print('\n📈 ANALYSE DES DONNÉES YNAB QUÉBÉCOISES:');
  print('-' * 60);

  final statsParMois = <String, Map<String, int>>{};
  final statsParCompte = <String, int>{};
  final statsParPayee = <String, int>{};
  final statsParCategorieGroup = <String, int>{};

  double totalRevenus = 0;
  double totalDepenses = 0;
  int transactionsAvecDollar = 0;

  for (var transaction in transactions) {
    // Stats par mois
    if (transaction['date'] != null) {
      final parts = transaction['date']!.split('/');
      if (parts.length == 3) {
        final mois = '${parts[2]}-${parts[1]}';
        statsParMois.putIfAbsent(mois, () => {'count': 0});
        statsParMois[mois]!['count'] = statsParMois[mois]!['count']! + 1;
      }
    }

    // Stats par compte
    if (transaction['account'] != null) {
      statsParCompte[transaction['account']!] =
          (statsParCompte[transaction['account']!] ?? 0) + 1;
    }

    // Stats par payee
    if (transaction['payee'] != null && transaction['payee']!.isNotEmpty) {
      statsParPayee[transaction['payee']!] =
          (statsParPayee[transaction['payee']!] ?? 0) + 1;
    }

    // Stats par category group
    if (transaction['category_group'] != null &&
        transaction['category_group']!.isNotEmpty) {
      statsParCategorieGroup[transaction['category_group']!] =
          (statsParCategorieGroup[transaction['category_group']!] ?? 0) + 1;
    }

    // Calculer totaux
    final outflow =
        double.tryParse(
          transaction['outflow']?.replaceAll('\$', '').replaceAll(',', '') ??
              '0',
        ) ??
        0;
    final inflow =
        double.tryParse(
          transaction['inflow']?.replaceAll('\$', '').replaceAll(',', '') ??
              '0',
        ) ??
        0;

    if (transaction['outflow']?.contains('\$') == true ||
        transaction['inflow']?.contains('\$') == true) {
      transactionsAvecDollar++;
    }

    totalRevenus += inflow;
    totalDepenses += outflow;
  }

  // Afficher les résultats
  print('💰 Revenus totaux: ${totalRevenus.toStringAsFixed(2)}\$ CAD');
  print('💸 Dépenses totales: ${totalDepenses.toStringAsFixed(2)}\$ CAD');
  print(
    '💵 Transactions avec \$: $transactionsAvecDollar/${transactions.length}',
  );

  print('\n📅 Répartition par mois (Top 10):');
  final moisOrdonnes = statsParMois.entries.toList()
    ..sort((a, b) => b.value['count']!.compareTo(a.value['count']!));
  for (var mois in moisOrdonnes.take(10)) {
    print('   ${mois.key}: ${mois.value['count']} transactions');
  }

  print('\n🏦 Répartition par compte:');
  final comptesOrdonnes = statsParCompte.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (var compte in comptesOrdonnes) {
    final pourcentage = (compte.value / transactions.length * 100)
        .toStringAsFixed(1);
    print('   ${compte.key}: ${compte.value} transactions ($pourcentage%)');
  }

  print('\n🏪 Top 10 Payees québécois:');
  final payeesOrdonnes = statsParPayee.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (var payee in payeesOrdonnes.take(10)) {
    print('   ${payee.key}: ${payee.value} transactions');
  }

  print('\n📁 Répartition par type de dépense:');
  final categoriesOrdonnes = statsParCategorieGroup.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (var categorie in categoriesOrdonnes) {
    final pourcentage = (categorie.value / transactions.length * 100)
        .toStringAsFixed(1);
    print(
      '   ${categorie.key}: ${categorie.value} transactions ($pourcentage%)',
    );
  }
}

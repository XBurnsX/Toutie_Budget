import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/import_csv_service.dart';

class PageImportCsv extends StatefulWidget {
  final String? fichierTest;
  final bool mappingTest;

  const PageImportCsv({super.key, this.fichierTest, this.mappingTest = false});

  @override
  State<PageImportCsv> createState() => _PageImportCsvState();
}

class _PageImportCsvState extends State<PageImportCsv> {
  final ImportCsvService _importService = ImportCsvService();

  // État de l'interface
  List<List<String>>? _donneesCsv;
  String? _cheminFichier;
  bool _premiereLigneEntetes = true;
  bool _chargementFichier = false;
  bool _importEnCours = false;
  double _progressImport = 0.0;

  // Mapping des colonnes
  final Map<String, int?> _mapping = {
    'date': null,
    'montant': null,
    'outflow': null, // Pour YNAB (dépenses)
    'inflow': null, // Pour YNAB (revenus)
    'type': null,
    'tiers': null,
    'compte': null,
    'enveloppe': null,
    'categorie': null,
    'note': null,
    'marqueur': null,
  };

  // Champs obligatoires
  final Set<String> _champsObligatoires = {'date', 'compte'};

  // Erreurs d'import
  final List<String> _erreurs = [];

  // Validation des comptes YNAB
  List<TransactionImport>? _transactionsImport;
  Set<String>? _comptesYnab;
  final Map<String, String> _mappingComptes = {};
  bool _validationComptesReussie = false;

  @override
  void initState() {
    super.initState();

    // Chargement automatique du fichier de test si spécifié
    if (widget.fichierTest != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _chargerFichierTest();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Import CSV'),
            if (widget.fichierTest != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '🧪 TEST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionSelectionFichier(),
            const SizedBox(height: 20),
            if (_donneesCsv != null) ...[
              _buildSectionConfiguration(),
              const SizedBox(height: 20),
              _buildSectionMapping(),
              const SizedBox(height: 20),
              _buildSectionPrevisualisation(),
              const SizedBox(height: 20),
              _buildSectionImport(),
            ],
            if (_erreurs.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionErreurs(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSelectionFichier() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    '📁 Sélection du fichier',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.fichierTest != null) ...[
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '(Mode Test Émulateur)',
                      style: TextStyle(
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (widget.fichierTest != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🧪 Mode test activé - Le fichier ${widget.fichierTest} sera chargé automatiquement avec mapping YNAB pré-configuré',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.fichierTest != null) const SizedBox(height: 10),
            if (_cheminFichier != null)
              Text(
                'Fichier ${widget.fichierTest != null ? "test " : ""}sélectionné: ${_cheminFichier!.split('/').last}',
                style: TextStyle(color: Colors.green[700]),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _chargementFichier ? null : _selectionnerFichier,
                  icon: _chargementFichier
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(
                    _chargementFichier ? 'Chargement...' : 'Sélectionner CSV',
                  ),
                ),
                const SizedBox(width: 10),
                if (_donneesCsv != null)
                  Chip(
                    label: Text('${_donneesCsv!.length} lignes'),
                    backgroundColor: widget.fichierTest != null
                        ? Colors.orange[100]
                        : Colors.blue[100],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionConfiguration() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚙️ Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              title: const Text('La première ligne contient les en-têtes'),
              value: _premiereLigneEntetes,
              onChanged: (value) {
                setState(() {
                  _premiereLigneEntetes = value ?? true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionMapping() {
    if (_donneesCsv == null || _donneesCsv!.isEmpty) return const SizedBox();

    final entetes = _premiereLigneEntetes && _donneesCsv!.isNotEmpty
        ? _donneesCsv![0]
        : List.generate(_donneesCsv![0].length, (i) => 'Colonne ${i + 1}');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '🔗 Mapping des colonnes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 8),
                if (_estFormatYnab())
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[300]!),
                    ),
                    child: Text(
                      'YNAB',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (_mapping['montant'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Text(
                      'Standard',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _estFormatYnab()
                  ? 'Format YNAB détecté - Les champs Montant, Type et Marqueur sont masqués automatiquement.'
                  : 'Associez chaque champ aux colonnes de votre fichier CSV.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _estFormatYnab() ? Colors.blue[700] : null,
                fontStyle: _estFormatYnab() ? FontStyle.italic : null,
              ),
            ),
            const SizedBox(height: 15),
            ..._mapping.keys
                .where((champ) => _doitAfficherChamp(champ))
                .map(
                  (champ) => _buildMappingRow(
                    champ,
                    entetes,
                    _champsObligatoires.contains(champ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// Détermine si un champ doit être affiché selon le format détecté
  bool _doitAfficherChamp(String champ) {
    final estFormatYnab = _estFormatYnab();

    if (estFormatYnab) {
      // Pour YNAB, masquer les champs qui ne s'appliquent pas
      return !['montant', 'type', 'marqueur'].contains(champ);
    } else {
      // Pour format standard, masquer les champs YNAB
      return !['outflow', 'inflow'].contains(champ);
    }
  }

  /// Détecte si le format YNAB est utilisé (présence d'outflow/inflow mappés)
  bool _estFormatYnab() {
    return _mapping['outflow'] != null || _mapping['inflow'] != null;
  }

  String _getLibelleChamp(String champ) {
    const Map<String, String> libelles = {
      'date': 'Date',
      'montant': 'Montant',
      'outflow': 'Outflow (YNAB)',
      'inflow': 'Inflow (YNAB)',
      'type': 'Type',
      'tiers': 'Tiers/Payeur',
      'compte': 'Compte',
      'enveloppe': 'Enveloppe',
      'categorie': 'Catégorie',
      'note': 'Note',
      'marqueur': 'Marqueur',
    };
    return libelles[champ] ?? champ.toUpperCase();
  }

  Widget _buildMappingRow(
    String champ,
    List<String> entetes,
    bool obligatoire,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              _getLibelleChamp(champ),
              style: TextStyle(
                fontWeight: obligatoire ? FontWeight.bold : FontWeight.normal,
                color: obligatoire ? Colors.red[700] : null,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          if (obligatoire)
            const Text(' *', style: TextStyle(color: Colors.red)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int?>(
              value: _mapping[champ],
              hint: const Text('Sélectionner une colonne'),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: obligatoire && _mapping[champ] == null
                    ? 'Champ obligatoire'
                    : null,
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('-- Non mappé --'),
                ),
                ...entetes.asMap().entries.map(
                  (entry) => DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text('${entry.key + 1}. ${entry.value}'),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _mapping[champ] = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionPrevisualisation() {
    if (_donneesCsv == null || !_mappingValide()) return const SizedBox();

    final lignesAffichees = _donneesCsv!.take(6).toList();
    if (_premiereLigneEntetes && lignesAffichees.isNotEmpty) {
      lignesAffichees.removeAt(0);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '👁️ Prévisualisation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'Aperçu des 5 premières transactions qui seront importées:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: _mapping.keys
                    .where((key) => _mapping[key] != null)
                    .map((key) => DataColumn(label: Text(key.toUpperCase())))
                    .toList(),
                rows: lignesAffichees
                    .map(
                      (ligne) => DataRow(
                        cells: _mapping.keys
                            .where((key) => _mapping[key] != null)
                            .map((key) {
                              final index = _mapping[key]!;
                              final valeur = index < ligne.length
                                  ? ligne[index]
                                  : '';
                              return DataCell(
                                Text(
                                  valeur.length > 20
                                      ? '${valeur.substring(0, 20)}...'
                                      : valeur,
                                ),
                              );
                            })
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionImport() {
    if (!_mappingValide()) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🚀 Import', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (_importEnCours) ...[
              LinearProgressIndicator(value: _progressImport),
              const SizedBox(height: 10),
              Text('Import en cours... ${(_progressImport * 100).toInt()}%'),
            ] else ...[
              Text(
                'Prêt à importer ${_getNombreTransactionsAImporter()} transactions.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _commencerImport,
                icon: const Icon(Icons.download),
                label: const Text('Commencer l\'import'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionErreurs() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ Erreurs d\'import',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.red[700]),
            ),
            const SizedBox(height: 10),
            ..._erreurs.map(
              (erreur) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Text(
                  '• $erreur',
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  _erreurs.clear();
                });
              },
              child: const Text('Effacer les erreurs'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectionnerFichier() async {
    setState(() {
      _chargementFichier = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        // Note: On accepte tous les fichiers pour compatibilité Google Drive
        // La validation du format se fera après sélection
      );

      if (result != null) {
        final fichier = result.files.single;
        final nomFichier = fichier.name ?? '';

        // Validation du type de fichier
        if (!nomFichier.toLowerCase().endsWith('.csv') &&
            !nomFichier.toLowerCase().endsWith('.txt')) {
          _afficherErreur(
            'Format non supporté. Veuillez sélectionner un fichier .csv ou .txt',
          );
          return;
        }

        _cheminFichier = fichier.path!;
        final donnees = await _importService.lireFichierCsv(_cheminFichier!);

        setState(() {
          _donneesCsv = donnees;
          // Réinitialiser le mapping
          _mapping.updateAll((key, value) => null);
          _erreurs.clear();
        });
      }
    } catch (e) {
      String message = 'Erreur lors de la lecture du fichier: $e';

      // Conseils spécifiques pour Google Drive
      if (e.toString().contains('path') || e.toString().contains('null')) {
        message +=
            '\n\n💡 Conseils Google Drive:\n'
            '• Téléchargez d\'abord le fichier sur votre appareil\n'
            '• Ou utilisez "Copier vers..." depuis Google Drive\n'
            '• Les fichiers cloud peuvent ne pas être accessibles directement';
      }

      _afficherErreur(message);
    } finally {
      setState(() {
        _chargementFichier = false;
      });
    }
  }

  bool _mappingValide() {
    // Vérifier les champs obligatoires de base
    final champsObligatoiresOk = _champsObligatoires.every(
      (champ) => _mapping[champ] != null,
    );

    // Vérifier qu'on a au moins un champ de montant (montant OU outflow/inflow)
    final montantOk =
        _mapping['montant'] != null ||
        (_mapping['outflow'] != null || _mapping['inflow'] != null);

    return champsObligatoiresOk && montantOk;
  }

  int _getNombreTransactionsAImporter() {
    if (_donneesCsv == null) return 0;
    int total = _donneesCsv!.length;
    if (_premiereLigneEntetes) total--;
    return total;
  }

  Future<void> _commencerImport() async {
    if (_donneesCsv == null || !_mappingValide()) return;

    try {
      // 1. Mapper les données CSV
      final transactionsImport = _importService.mapperDonneesCsv(
        _donneesCsv!,
        _mapping
            .map((key, value) => MapEntry(key, value ?? -1))
            .cast<String, int>(),
        _premiereLigneEntetes,
      );

      // 2. Extraire les comptes uniques pour validation
      final comptesYnab = _importService.extraireComptesUniques(
        transactionsImport,
      );

      setState(() {
        _transactionsImport = transactionsImport;
        _comptesYnab = comptesYnab;
      });

      // 3. Afficher le modal de validation des comptes
      await _afficherModalValidationComptes();
    } catch (e) {
      _afficherErreur('Erreur lors de la préparation: $e');
    }
  }

  Future<void> _finaliserImport() async {
    if (_transactionsImport == null || !_validationComptesReussie) return;

    // Afficher l'avertissement avant l'import
    final confirmerImport = await _afficherAvertissementImport();
    if (!confirmerImport) return;

    setState(() {
      _importEnCours = true;
      _progressImport = 0.0;
      _erreurs.clear();
    });

    try {
      // 1. Appliquer le mapping des comptes
      final transactionsAvecComptes = _importService.appliquerMappingComptes(
        _transactionsImport!,
        _mappingComptes,
      );

      // 2. Valider et transformer
      final transactions = await _importService
          .validerEtTransformerTransactions(
            transactionsAvecComptes,
            (erreur) {
              setState(() {
                _erreurs.add(erreur);
              });
            },
            (progress) {
              setState(() {
                _progressImport = progress;
              });
            },
          );

      // 3. Importer avec traitement mois par mois
      await _importService.importerTransactions(transactions, (progress) {
        setState(() {
          _progressImport = progress;
        });
      });

      // 4. Succès
      _afficherSucces(
        'Import terminé! ${transactions.length} transactions importées avec traitement mois par mois.',
      );
    } catch (e) {
      _afficherErreur('Erreur lors de l\'import: $e');
    } finally {
      setState(() {
        _importEnCours = false;
        _progressImport = 0.0;
      });
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _afficherModalValidationComptes() async {
    if (_comptesYnab == null || _comptesYnab!.isEmpty) {
      _afficherErreur('Aucun compte détecté dans le CSV');
      return;
    }

    // Obtenir la liste des comptes disponibles
    final comptesDisponibles = await _obtenirComptesDisponibles();

    // Pré-remplir le mapping avec les correspondances exactes
    _mappingComptes.clear();
    for (String compteYnab in _comptesYnab!) {
      final correspondance = comptesDisponibles.keys.firstWhere(
        (nom) =>
            nom.toLowerCase().contains(compteYnab.toLowerCase()) ||
            compteYnab.toLowerCase().contains(nom.toLowerCase()),
        orElse: () => '',
      );
      if (correspondance.isNotEmpty) {
        _mappingComptes[compteYnab] = correspondance;
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('🔗 Validation des Comptes'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Associez vos comptes YNAB avec vos comptes Toutie Budget:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ...(_comptesYnab!.map((compteYnab) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                compteYnab,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _mappingComptes[compteYnab],
                                hint: const Text('Choisir un compte'),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: comptesDisponibles.keys.map((nom) {
                                  return DropdownMenuItem<String>(
                                    value: nom,
                                    child: Text(nom),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setModalState(() {
                                    if (value != null) {
                                      _mappingComptes[compteYnab] = value;
                                    } else {
                                      _mappingComptes.remove(compteYnab);
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      })),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: _mappingComptes.length == _comptesYnab!.length
                      ? () {
                          setState(() {
                            _validationComptesReussie = true;
                          });
                          Navigator.of(context).pop();
                          _finaliserImport();
                        }
                      : null,
                  child: const Text('Continuer l\'import'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, String>> _obtenirComptesDisponibles() async {
    try {
      return await _importService.obtenirComptesDisponibles();
    } catch (e) {
      _afficherErreur('Erreur lors du chargement des comptes: $e');
      return {};
    }
  }

  Future<void> _chargerFichierTest() async {
    if (widget.fichierTest == null) return;

    setState(() {
      _chargementFichier = true;
    });

    try {
      List<List<String>> donnees;

      // Créer des données de test directement dans le code pour éviter les problèmes de fichiers
      if (widget.fichierTest == 'exemple_csv.csv') {
        donnees = [
          [
            'Account',
            'Date',
            'Payee',
            'Category Group',
            'Category',
            'Memo',
            'Outflow',
            'Inflow',
          ],
          // === DÉCEMBRE 2024 ===
          [
            'WealthSimple Cash',
            '30/12/2024',
            'Paye Décembre',
            'Inflow',
            'Ready to Assign',
            '',
            '0.00\$',
            '1200.00\$',
          ],
          [
            'WealthSimple Cash',
            '15/12/2024',
            'Bonus Noël',
            'Inflow',
            'Ready to Assign',
            '',
            '0.00\$',
            '500.00\$',
          ],
          [
            'WealthSimple Cash',
            '01/12/2024',
            'Freelance',
            'Inflow',
            'Ready to Assign',
            '',
            '0.00\$',
            '300.00\$',
          ],
          [
            'WealthSimple Cash',
            '10/12/2024',
            'Épicerie Déc',
            'Dépense Obligatoire',
            'Épicerie',
            '',
            '75.50\$',
            '0.00\$',
          ],
          // === NOVEMBRE 2024 ===
          [
            'WealthSimple Cash',
            '30/11/2024',
            'Paye Novembre',
            'Inflow',
            'Ready to Assign',
            '',
            '0.00\$',
            '1150.00\$',
          ],
          [
            'WealthSimple Cash',
            '15/11/2024',
            'Remboursement',
            'Inflow',
            'Ready to Assign',
            '',
            '0.00\$',
            '200.00\$',
          ],
          [
            'WealthSimple Cash',
            '05/11/2024',
            'Restaurant Nov',
            'Dépense Non Obligatoire',
            'Restaurant',
            '',
            '45.00\$',
            '0.00\$',
          ],
          // === OCTOBRE 2024 ===
          [
            'WealthSimple Cash',
            '31/10/2024',
            'Paye Octobre',
            'Inflow',
            'Ready to Assign',
            '',
            '0.00\$',
            '1100.00\$',
          ],
          [
            'WealthSimple Cash',
            '20/10/2024',
            'Vente Usagé',
            'Inflow',
            'Ready to Assign',
            '',
            '0.00\$',
            '150.00\$',
          ],
          [
            'WealthSimple Cash',
            '10/10/2024',
            'Commission',
            'Inflow',
            'Ready to Assign',
            '',
            '0.00\$',
            '250.00\$',
          ],
          [
            'WealthSimple Cash',
            '15/10/2024',
            'Essence Oct',
            'Dépense Non Obligatoire',
            'Essence',
            '',
            '60.00\$',
            '0.00\$',
          ],
          // === SEPTEMBRE 2024 ===
          [
            'WealthSimple Cash',
            '30/09/2024',
            'Paye Septembre',
            'Inflow',
            'Ready to Assign',
            '',
            '0.00\$',
            '1050.00\$',
          ],
          [
            'WealthSimple Cash',
            '15/09/2024',
            'Cadeau',
            'Inflow',
            'Ready to Assign',
            '',
            '0.00\$',
            '100.00\$',
          ],
          [
            'WealthSimple Cash',
            '05/09/2024',
            'Loyer Sept',
            'Dépense Obligatoire',
            'Logement',
            '',
            '800.00\$',
            '0.00\$',
          ],
        ];
      } else {
        // Essayer de charger le fichier normalement
        donnees = await _importService.lireFichierCsv(widget.fichierTest!);
      }

      setState(() {
        _donneesCsv = donnees;
        _cheminFichier = widget.fichierTest;
        _erreurs.clear();

        // Appliquer le mapping automatique YNAB si demandé
        if (widget.mappingTest) {
          _appliquerMappingYnabAutomatique();
        }
      });

      _afficherSucces(
        '✅ Fichier de test ${widget.fichierTest} chargé automatiquement ! (${donnees.length - 1} transactions)',
      );
    } catch (e) {
      _afficherErreur('❌ Erreur lors du chargement du fichier test: $e');
    } finally {
      setState(() {
        _chargementFichier = false;
      });
    }
  }

  void _appliquerMappingYnabAutomatique() {
    if (_donneesCsv == null || _donneesCsv!.isEmpty) return;

    // Obtenir les en-têtes
    final entetes = _premiereLigneEntetes && _donneesCsv!.isNotEmpty
        ? _donneesCsv![0]
        : List.generate(_donneesCsv![0].length, (i) => 'Colonne ${i + 1}');

    // Mapping automatique pour YNAB
    final mappingAuto = <String, String>{
      'Account': 'compte',
      'Date': 'date',
      'Payee': 'tiers',
      'Category Group': 'categorie',
      'Category': 'enveloppe',
      'Memo': 'note',
      'Outflow': 'outflow',
      'Inflow': 'inflow',
    };

    // Appliquer le mapping automatique
    for (int i = 0; i < entetes.length; i++) {
      final entete = entetes[i];
      if (mappingAuto.containsKey(entete)) {
        final champ = mappingAuto[entete]!;
        setState(() {
          _mapping[champ] = i;
        });
      }
    }

    _afficherSucces('🎯 Mapping YNAB appliqué automatiquement !');
  }

  /// Affiche un avertissement avant l'import concernant la remise à zéro des enveloppes
  Future<bool> _afficherAvertissementImport() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 24),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '⚠️ Import CSV',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: const SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATTENTION : Remise à zéro intelligente des enveloppes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Cet import va traiter vos données mois par mois et :',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '✓ Remettre les enveloppes à 0\$ au début de chaque nouveau mois',
                      style: TextStyle(fontSize: 14, color: Colors.green),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '✓ Transférer l\'argent existant vers le "Prêt à placer" du compte correspondant',
                      style: TextStyle(fontSize: 14, color: Colors.green),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '✓ Préserver toutes les statistiques mensuelles et le top 5 des dépenses',
                      style: TextStyle(fontSize: 14, color: Colors.green),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '✓ Maintenir l\'historique des transactions',
                      style: TextStyle(fontSize: 14, color: Colors.green),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Résultat final :',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Enveloppes avec leurs soldes finaux corrects',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      '• Statistiques mensuelles précises',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      '• Prêt à placer ajusté avec les anciens soldes',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Cette opération ne peut pas être annulée.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continuer l\'import'),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:toutie_budget/widgets/numeric_keyboard.dart';
import 'package:toutie_budget/services/allocation_service.dart';

// Utilisé pour la détection des couleurs négatives/positives si besoin.
// ignore: unused_import
import 'package:toutie_budget/services/color_service.dart';

class AssignationBottomSheet extends StatefulWidget {
  final Map<String, dynamic> enveloppe;
  final List<Map<String, dynamic>> comptes;
  final VoidCallback? onAssignationComplete;
  const AssignationBottomSheet({
    super.key,
    required this.enveloppe,
    required this.comptes,
    this.onAssignationComplete,
  });

  @override
  State<AssignationBottomSheet> createState() => _AssignationBottomSheetState();
}

class _AssignationBottomSheetState extends State<AssignationBottomSheet> {
  late TextEditingController _ctrl;
  String? _compteId;
  late double _montantNecessaire;

  // Conserve une référence vers le BuildContext du bottom-sheet pour les dialogs
  late BuildContext _sheetContext;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '0.00');
    _compteId = widget.enveloppe['provenance_compte_id'];
    _calcMontantAsync();
  }

  Future<void> _calcMontantAsync() async {
    final montant = await _calcMontant(widget.enveloppe);
    if (mounted) {
      setState(() {
        _montantNecessaire = montant;
      });
    }
  }

  // Déterminer la collection du compte selon son type
  String _getCompteCollection(String compteId) {
    final compte = widget.comptes.firstWhere(
      (c) => c['id'].toString() == compteId,
      orElse: () => <String, Object>{},
    );

    final type = (compte['type'] ?? '').toString().toLowerCase();

    if (type.contains('chèque') || type.contains('cheque')) {
      return 'comptes_cheques';
    } else if (type.contains('crédit') || type.contains('credit')) {
      return 'comptes_credits';
    } else if (type.contains('investissement')) {
      return 'comptes_investissement';
    } else if (type.contains('dette')) {
      return 'comptes_dettes';
    } else {
      return 'comptes_cheques'; // Par défaut
    }
  }

  Future<double> _calcMontant(Map<String, dynamic> env) async {
    final double objectifTotal = (env['objectif'] as num?)?.toDouble() ?? 0.0;

    // Calculer le solde avec les allocations mensuelles
    final soldeEnvNullable = await AllocationService.calculerSoldeEnveloppe(
      enveloppeId: env['id'],
      mois: DateTime.now(),
    );
    // Convertir la valeur nullable en non-nullable avec une valeur par défaut de 0.0
    final double soldeEnv = soldeEnvNullable ?? 0.0;

    final String freq =
        (env['frequence_objectif']?.toString() ?? '').toLowerCase();
    final DateTime now = DateTime.now();

    if (freq.contains('mensuel')) {
      return (objectifTotal - soldeEnv).clamp(0.0, double.infinity);
    }

    if (freq.contains('bihebdo')) {
      return objectifTotal; // par période de 2 semaines – ajustement possible plus tard
    }

    if (freq.contains('annuel')) {
      DateTime cible;
      if (env['objectif_date'] != null) {
        try {
          final temp = DateTime.parse(env['objectif_date']);
          cible = DateTime(now.year, temp.month, temp.day);
          if (cible.isBefore(now)) {
            cible = DateTime(now.year + 1, temp.month, temp.day);
          }
        } catch (_) {
          cible = DateTime(now.year, 12, 31);
        }
      } else {
        cible = DateTime(now.year, 12, 31);
      }
      int moisRestants =
          (cible.year - now.year) * 12 + (cible.month - now.month) + 1;
      moisRestants = moisRestants < 1 ? 1 : moisRestants;
      return (objectifTotal / moisRestants).clamp(0.0, double.infinity);
    }

    if (freq.contains('date')) {
      if (env['objectif_date'] != null) {
        try {
          final cible = DateTime.parse(env['objectif_date']);
          int moisRestants =
              (cible.year - now.year) * 12 + (cible.month - now.month) + 1;
          moisRestants = moisRestants < 1 ? 1 : moisRestants;
          return ((objectifTotal - soldeEnv) / moisRestants)
              .clamp(0.0, double.infinity);
        } catch (_) {}
      }
    }
    return objectifTotal.clamp(0.0, double.infinity);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _sheetContext = context;

    final comptesDisponibles = widget.comptes.where((c) {
      final typeStr = (c['type'] ?? '').toString().toLowerCase();
      // Inclure tous les types de comptes sauf les dettes et investissements
      return !typeStr.contains('dette') &&
          !typeStr.contains('investissement') &&
          c['estArchive'] != true;
    }).toList();

    // Design adaptatif selon la plateforme
    if (kIsWeb) {
      return _buildWebVersion(comptesDisponibles);
    } else {
      return _buildMobileVersion(comptesDisponibles);
    }
  }

  Widget _buildWebVersion(List<Map<String, dynamic>> comptesDisponibles) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Assignation d\'argent',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section compte
            Text(
              'Compte source',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                isExpanded: true,
                value: comptesDisponibles.any((c) => c['id'] == _compteId)
                    ? _compteId
                    : null,
                hint: const Text('Sélectionner un compte'),
                underline: const SizedBox(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                items: comptesDisponibles.map((c) {
                  final pret = (c['pretAPlacer'] as num?)?.toDouble() ?? 0.0;
                  final color = Color(c['couleur'] as int? ?? 0xFF2196F3);
                  return DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            c['nom']?.toString() ?? 'Compte',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${pret.toStringAsFixed(2)}\u00A0\$',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _compteId = val),
              ),
            ),
            const SizedBox(height: 24),

            // Section montant
            Text(
              'Montant à assigner',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixText: '\$',
                      hintText: '0.00',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _ctrl.text = _montantNecessaire.toStringAsFixed(2);
                    });
                  },
                  child: const Text('Montant suggéré'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _effectuerAssignation,
                    child: const Text('Assigner'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileVersion(List<Map<String, dynamic>> comptesDisponibles) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _ctrl.text = '${_montantNecessaire.toStringAsFixed(2)} \$';
                  });
                },
                child: const Text('Assigné'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: comptesDisponibles.any((c) => c['id'] == _compteId)
                      ? _compteId
                      : null,
                  hint: const Text('Compte'),
                  items: comptesDisponibles.map((c) {
                    final pret = (c['pretAPlacer'] as num?)?.toDouble() ?? 0.0;
                    final color = Color(c['couleur'] as int? ?? 0xFF2196F3);
                    return DropdownMenuItem(
                      value: c['id'].toString(),
                      child: Row(
                        children: [
                          Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(c['nom']?.toString() ?? 'Compte',
                                  overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Text(
                            '${pret.toStringAsFixed(2)}\u00A0\$',
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _compteId = val),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                  onPressed: () {/* TODO */}, child: const Text('Détail')),
              const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 8),
          NumericKeyboard(
            controller: _ctrl,
            onClear: () => _ctrl.clear(),
            onDone: _effectuerAssignation,
          ),
        ],
      ),
    );
  }

  // ========  LOGIQUE D'ASSIGNATION  ========

  double _parseMontant(String text) {
    final cleaned =
        text.replaceAll(RegExp(r'[^0-9\-,\.]'), '').replaceAll(',', '.').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  bool _peutAssigner() => _compteId != null;

  void _afficherErreur(String message) {
    showDialog(
      context: _sheetContext,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Erreur',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white70,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 20, color: Colors.white),
            label: const Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(_sheetContext).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(_sheetContext).pop(),
          ),
        ],
      ),
    );
  }

  void _afficherMessageErreurMelangeFonds() {
    showDialog(
      context: _sheetContext,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.grey[900],
        title: const Text(
          "Impossible d'ajouter de l'argent",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          "Cette enveloppe contient déjà de l'argent provenant d'un autre compte.\nVous ne pouvez pas mélanger les fonds.",
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 20, color: Colors.white),
            label: const Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(_sheetContext).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(_sheetContext).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _effectuerAssignation() async {
    if (!_peutAssigner()) {
      _afficherErreur('Veuillez sélectionner un compte.');
      return;
    }

    final montantDouble = _parseMontant(_ctrl.text);

    if (montantDouble <= 0) {
      _afficherErreur('Le montant doit être supérieur à 0.');
      return;
    }

    final compte = widget.comptes.firstWhere(
      (c) => c['id'] == _compteId,
      orElse: () => <String, Object>{},
    );

    final pretAPlacer = (compte['pretAPlacer'] as num?)?.toDouble() ?? 0.0;

    if (pretAPlacer < montantDouble) {
      _afficherErreur('Solde insuffisant dans le compte sélectionné.');
      return;
    }

    try {
      // Récupérer le compte sélectionné
      final comptes = widget.comptes;
      final compte = comptes.firstWhere((c) => c['id'] == _compteId);
      // print('🔍 Compte sélectionné: $_compteId');
      // print('🔍 Compte trouvé: ${compte['nom']} (${compte['id']})');

      // Créer l'allocation
      await AllocationService.creerAllocationMensuelle(
        enveloppeId: widget.enveloppe['id'],
        montant: _ctrl.text.isEmpty ? 0.0 : double.parse(_ctrl.text),
        compteSourceId: compte['id'],
        collectionCompteSource: compte['collection'] ?? 'comptes_cheques',
        estAllocation: true,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onAssignationComplete?.call();
      }
    } catch (e) {
      // print('❌ Erreur assignation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'assignation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

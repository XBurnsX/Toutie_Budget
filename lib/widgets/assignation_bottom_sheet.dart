import 'package:flutter/material.dart';
import 'package:toutie_budget/widgets/numeric_keyboard.dart';
import 'package:toutie_budget/services/argent_service.dart';

// Utilisé pour la détection des couleurs négatives/positives si besoin.
// ignore: unused_import
import 'package:toutie_budget/services/color_service.dart';

class AssignationBottomSheet extends StatefulWidget {
  final Map<String, dynamic> enveloppe;
  final List<Map<String, dynamic>> comptes;
  const AssignationBottomSheet(
      {super.key, required this.enveloppe, required this.comptes});

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
    _montantNecessaire = _calcMontant(widget.enveloppe);
  }

  double _calcMontant(Map<String, dynamic> env) {
    final double objectifTotal = (env['objectif'] as num?)?.toDouble() ?? 0.0;
    final double soldeEnv = (env['solde'] as num?)?.toDouble() ?? 0.0;
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
          if (cible.isBefore(now))
            cible = DateTime(now.year + 1, temp.month, temp.day);
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
      return (typeStr.contains('chèque') || typeStr.contains('cheque')) &&
          c['estArchive'] != true;
    }).toList();

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
      await ArgentService().virerArgent(
        sourceId: _compteId!,
        destinationId: widget.enveloppe['id'].toString(),
        montant: montantDouble,
      );

      if (mounted) {
        Navigator.of(_sheetContext).pop();
        ScaffoldMessenger.of(_sheetContext).showSnackBar(
          SnackBar(
            content: Text(
              'Assignation de ${montantDouble.toStringAsFixed(2)} \$ réussie',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('mélanger') ||
          errorMsg.contains('provient') ||
          errorMsg.contains('autre compte')) {
        _afficherMessageErreurMelangeFonds();
      } else {
        _afficherErreur('Erreur lors de l\'assignation : $e');
      }
    }
  }
}

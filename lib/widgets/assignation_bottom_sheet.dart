import 'package:flutter/material.dart';
import 'package:toutie_budget/widgets/numeric_keyboard.dart';

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
                    _ctrl.text = _montantNecessaire.toStringAsFixed(2);
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
          NumericKeyboard(controller: _ctrl, onClear: () => _ctrl.clear()),
        ],
      ),
    );
  }
}

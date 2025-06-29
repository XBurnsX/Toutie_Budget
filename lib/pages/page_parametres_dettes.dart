import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:toutie_budget/models/dette.dart';
import 'package:toutie_budget/services/dette_service.dart';
import 'package:toutie_budget/widgets/numeric_keyboard.dart';
import 'package:toutie_budget/widgets/month_picker.dart';

class PageParametresDettes extends StatefulWidget {
  final Dette dette;

  const PageParametresDettes({super.key, required this.dette});

  @override
  State<PageParametresDettes> createState() => _PageParametresDettesState();
}

class _PageParametresDettesState extends State<PageParametresDettes> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs principaux
  final _tauxController = TextEditingController();
  final _dateDebutController = TextEditingController();
  final _dateFinController = TextEditingController();
  final _montantMensuelController = TextEditingController();
  final _prixAchatController = TextEditingController();
  final _nombrePaiementsController = TextEditingController();
  final _paiementsEffectuesController = TextEditingController();

  // Simulateur
  final _simulateurTauxController = TextEditingController();
  final _simulateurPaiementController = TextEditingController();
  final _simulateurPrincipalController = TextEditingController();
  final _simulateurDureeController = TextEditingController();

  bool _montreSimulateur = false;
  double? _tauxCalcule;
  double? _paiementCalcule;
  double? _soldeRestantCalcule;
  double? _coutTotalCalcule;
  String? _erreurSimulateur;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  void _chargerDonnees() {
    if (widget.dette.tauxInteret != null) {
      _tauxController.text = widget.dette.tauxInteret!.toStringAsFixed(2);
    }

    // Date de début (par défaut aujourd'hui)
    final dateDebut = widget.dette.dateDebut ?? DateTime.now();
    _dateDebutController.text = _formaterDate(dateDebut);

    if (widget.dette.dateFin != null) {
      _dateFinController.text = _formaterDate(widget.dette.dateFin!);
    }

    if (widget.dette.montantMensuel != null) {
      _montantMensuelController.text = widget.dette.montantMensuel!
          .toStringAsFixed(2);
    }

    if (widget.dette.prixAchat != null) {
      _prixAchatController.text = widget.dette.prixAchat!.toStringAsFixed(2);
    }

    if (widget.dette.nombrePaiements != null) {
      _nombrePaiementsController.text = widget.dette.nombrePaiements!
          .toString();
    }

    if (widget.dette.paiementsEffectues != null) {
      _paiementsEffectuesController.text = widget.dette.paiementsEffectues!
          .toString();
    } else {
      // Calculer automatiquement les paiements effectués
      _calculerPaiementsEffectues();
    }
  }

  void _calculerPaiementsEffectues() {
    final dateDebut = _parseDate(_dateDebutController.text);
    if (dateDebut != null) {
      final maintenant = DateTime.now();
      final mois =
          (maintenant.year - dateDebut.year) * 12 +
          (maintenant.month - dateDebut.month);
      final paiementsEffectues = mois > 0 ? mois : 1;
      _paiementsEffectuesController.text = paiementsEffectues.toString();
    }
  }

  String _formaterDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres de la dette'),
        actions: [
          IconButton(
            icon: Icon(_montreSimulateur ? Icons.calculate : Icons.science),
            onPressed: () {
              setState(() {
                _montreSimulateur = !_montreSimulateur;
                if (_montreSimulateur) {
                  _simulateurPrincipalController.text =
                      _prixAchatController.text;
                  _simulateurDureeController.text =
                      _nombrePaiementsController.text;
                  _calculerSimulateur('');
                }
              });
            },
            tooltip: _montreSimulateur
                ? 'Masquer simulateur'
                : 'Afficher simulateur',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_montreSimulateur) ...[
                _buildSimulateur(),
                const Divider(height: 32),
              ],
              _buildFormulaire(),
              const SizedBox(height: 16),
              _buildCalculsAutomatiques(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sauvegarder,
        label: const Text('Sauvegarder'),
        icon: const Icon(Icons.save),
      ),
    );
  }

  Widget _buildSimulateur() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Simulateur de prêt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _simulateurPrincipalController,
                    decoration: const InputDecoration(
                      labelText: 'Prix d\'achat (\$)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: _calculerSimulateur,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _simulateurDureeController,
                    decoration: const InputDecoration(
                      labelText: 'Durée (mois)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: _calculerSimulateur,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _simulateurTauxController,
                    decoration: const InputDecoration(
                      labelText: 'Taux APR (%)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: _calculerPaiement,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _simulateurPaiementController,
                    decoration: const InputDecoration(
                      labelText: 'Paiement mensuel (\$)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: _calculerSimulateur,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_tauxCalcule != null ||
                _paiementCalcule != null ||
                _erreurSimulateur != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _erreurSimulateur != null
                      ? Colors.red.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _erreurSimulateur != null ? Colors.red : Colors.blue,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_erreurSimulateur != null)
                      Text(
                        _erreurSimulateur!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    if (_paiementCalcule != null)
                      Text(
                        'Paiement mensuel: \$${_paiementCalcule!.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (_coutTotalCalcule != null)
                      Text(
                        'Coût total: \$${_coutTotalCalcule!.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (_soldeRestantCalcule != null)
                      Text(
                        'Solde restant: \$${_soldeRestantCalcule!.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _calculerSimulateur(String _) {
    setState(() {
      _tauxCalcule = null;
      _paiementCalcule = null;
      _soldeRestantCalcule = null;
      _coutTotalCalcule = null;
      _erreurSimulateur = null;
    });

    try {
      final principal = double.tryParse(_simulateurPrincipalController.text);
      final duree = int.tryParse(_simulateurDureeController.text);
      final taux = double.tryParse(_simulateurTauxController.text);
      final paiement = double.tryParse(_simulateurPaiementController.text);

      if (principal != null && duree != null && duree > 0) {
        if (taux != null) {
          // Calculer le paiement mensuel avec le taux donné
          final tauxMensuel = taux / 100 / 12;
          final montantMensuel =
              principal *
              (tauxMensuel * math.pow(1 + tauxMensuel, duree)) /
              (math.pow(1 + tauxMensuel, duree) - 1);

          final coutTotal = montantMensuel * duree;

          setState(() {
            _paiementCalcule = montantMensuel;
            _coutTotalCalcule = coutTotal;
          });
        } else if (paiement != null) {
          // Calculer le taux avec le paiement donné
          final taux = _calculerTauxPourPaiementMensuel(
            principal: principal,
            paiementMensuel: paiement,
            nombrePaiements: duree,
          );

          final coutTotal = paiement * duree;

          setState(() {
            _tauxCalcule = taux;
            _coutTotalCalcule = coutTotal;
          });
        }
      }
    } catch (e) {
      setState(() {
        _erreurSimulateur = 'Erreur de calcul: $e';
      });
    }
  }

  void _calculerPaiement(String _) {
    _calculerSimulateur('');
  }

  double _calculerTauxPourPaiementMensuel({
    required double principal,
    required double paiementMensuel,
    required int nombrePaiements,
  }) {
    double low = 0.0;
    double high = 2.0; // 200% annuel max
    double epsilon = 0.01;

    while ((high - low) > 1e-6) {
      double mid = (low + high) / 2;
      double tauxMensuel = mid / 12;

      // Calculer le paiement avec ce taux
      double numerateur =
          principal * tauxMensuel * math.pow(1 + tauxMensuel, nombrePaiements);
      double denominateur = math.pow(1 + tauxMensuel, nombrePaiements) - 1;
      double paiementCalcule = numerateur / denominateur;

      if ((paiementCalcule - paiementMensuel).abs() < epsilon) {
        return mid * 100; // Retourne le taux annuel en %
      } else if (paiementCalcule > paiementMensuel) {
        // Paiement trop élevé, il faut baisser le taux
        high = mid;
      } else {
        // Paiement trop bas, il faut augmenter le taux
        low = mid;
      }
    }

    return (low + high) / 2 * 100;
  }

  Widget _buildFormulaire() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paramètres de la dette',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Date de début du prêt
        TextFormField(
          controller: _dateDebutController,
          decoration: const InputDecoration(
            labelText: 'Date de début du prêt',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
            helperText: 'Date à laquelle le prêt a été contracté',
          ),
          readOnly: true,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate:
                  _parseDate(_dateDebutController.text) ?? DateTime.now(),
              firstDate: DateTime.now().subtract(
                const Duration(days: 3650),
              ), // 10 ans en arrière
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() {
                _dateDebutController.text = _formaterDate(date);
                _calculerPaiementsEffectues();
              });
            }
          },
        ),
        const SizedBox(height: 16),

        // Taux d'intérêt
        TextFormField(
          controller: _tauxController,
          decoration: const InputDecoration(
            labelText: 'Taux d\'intérêt annuel (%)',
            border: OutlineInputBorder(),
            helperText: 'Ex: 25.07 pour 25.07% APR',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer un taux d\'intérêt';
            }
            final taux = double.tryParse(value);
            if (taux == null || taux < 0) {
              return 'Veuillez entrer un taux valide';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Prix d'achat
        TextFormField(
          controller: _prixAchatController,
          decoration: const InputDecoration(
            labelText: 'Prix d\'achat (\$)',
            border: OutlineInputBorder(),
            helperText: 'Montant initial de la dette',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer un prix d\'achat';
            }
            final prix = double.tryParse(value);
            if (prix == null || prix <= 0) {
              return 'Veuillez entrer un prix valide';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Durée du prêt
        TextFormField(
          controller: _nombrePaiementsController,
          decoration: const InputDecoration(
            labelText: 'Durée du prêt (mois)',
            border: OutlineInputBorder(),
            helperText: 'Nombre total de paiements mensuels',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer la durée du prêt';
            }
            final nombre = int.tryParse(value);
            if (nombre == null || nombre <= 0) {
              return 'Veuillez entrer une durée valide';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Paiements effectués
        TextFormField(
          controller: _paiementsEffectuesController,
          decoration: const InputDecoration(
            labelText: 'Paiements effectués',
            border: OutlineInputBorder(),
            helperText: 'Nombre de paiements déjà effectués',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer le nombre de paiements effectués';
            }
            final nombre = int.tryParse(value);
            if (nombre == null || nombre < 0) {
              return 'Veuillez entrer un nombre valide';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Montant mensuel (calculé automatiquement)
        TextFormField(
          controller: _montantMensuelController,
          decoration: const InputDecoration(
            labelText: 'Montant mensuel (\$)',
            border: OutlineInputBorder(),
            helperText: 'Montant à payer chaque mois (calculé automatiquement)',
          ),
          keyboardType: TextInputType.number,
          readOnly: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez calculer le montant mensuel';
            }
            final montant = double.tryParse(value);
            if (montant == null || montant <= 0) {
              return 'Veuillez calculer un montant valide';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Date de fin (calculée automatiquement)
        TextFormField(
          controller: _dateFinController,
          decoration: const InputDecoration(
            labelText: 'Date de fin (calculée)',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
            helperText: 'Date de fin calculée automatiquement',
          ),
          readOnly: true,
        ),
      ],
    );
  }

  Widget _buildCalculsAutomatiques() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Calculs automatiques',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _calculerMontantMensuel,
              icon: const Icon(Icons.calculate),
              label: const Text('Calculer le montant mensuel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (_montantMensuelController.text.isNotEmpty) ...[
              _buildResultatCalcul(
                'Montant mensuel',
                _montantMensuelController.text,
              ),
              _buildResultatCalcul('Coût total', _calculerCoutTotal()),
              _buildResultatCalcul('Solde restant', _calculerSoldeRestant()),
              _buildResultatCalcul('Intérêts payés', _calculerInteretsPayes()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultatCalcul(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            valeur,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _calculerMontantMensuel() {
    try {
      final prixAchat = double.tryParse(_prixAchatController.text);
      final tauxInteret = double.tryParse(_tauxController.text);
      final nombrePaiements = int.tryParse(_nombrePaiementsController.text);

      if (prixAchat != null && tauxInteret != null && nombrePaiements != null) {
        final tauxMensuel = tauxInteret / 100 / 12;
        final montantMensuel =
            prixAchat *
            (tauxMensuel * math.pow(1 + tauxMensuel, nombrePaiements)) /
            (math.pow(1 + tauxMensuel, nombrePaiements) - 1);

        setState(() {
          _montantMensuelController.text = montantMensuel.toStringAsFixed(2);
          _calculerDateFin();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur de calcul: $e')));
    }
  }

  void _calculerDateFin() {
    final dateDebut = _parseDate(_dateDebutController.text);
    final nombrePaiements = int.tryParse(_nombrePaiementsController.text);

    if (dateDebut != null && nombrePaiements != null) {
      final dateFin = DateTime(
        dateDebut.year,
        dateDebut.month + nombrePaiements,
        dateDebut.day,
      );
      _dateFinController.text = _formaterDate(dateFin);
    }
  }

  String _calculerCoutTotal() {
    final montantMensuel = double.tryParse(_montantMensuelController.text);
    final nombrePaiements = int.tryParse(_nombrePaiementsController.text);

    if (montantMensuel != null && nombrePaiements != null) {
      final coutTotal = montantMensuel * nombrePaiements;
      return '\$${coutTotal.toStringAsFixed(2)}';
    }
    return '—';
  }

  String _calculerSoldeRestant() {
    final coutTotal = double.tryParse(
      _calculerCoutTotal().replaceAll('\$', '').replaceAll('—', '0'),
    );
    final paiementsEffectues = int.tryParse(_paiementsEffectuesController.text);
    final montantMensuel = double.tryParse(_montantMensuelController.text);

    if (coutTotal != null &&
        paiementsEffectues != null &&
        montantMensuel != null) {
      final totalPaye = montantMensuel * paiementsEffectues;
      final soldeRestant = coutTotal - totalPaye;
      return '\$${soldeRestant.toStringAsFixed(2)}';
    }
    return '—';
  }

  String _calculerInteretsPayes() {
    final prixAchat = double.tryParse(_prixAchatController.text);
    final paiementsEffectues = int.tryParse(_paiementsEffectuesController.text);
    final montantMensuel = double.tryParse(_montantMensuelController.text);
    final soldeRestant = double.tryParse(
      _calculerSoldeRestant().replaceAll('\$', '').replaceAll('—', '0'),
    );

    if (prixAchat != null &&
        paiementsEffectues != null &&
        montantMensuel != null &&
        soldeRestant != null) {
      final totalPaye = montantMensuel * paiementsEffectues;
      final capitalRembourse = prixAchat - soldeRestant;
      final interetsPayes = totalPaye - capitalRembourse;
      return '\$${interetsPayes.toStringAsFixed(2)}';
    }
    return '—';
  }

  void _sauvegarder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final detteModifiee = widget.dette.copyWith(
        tauxInteret: double.parse(_tauxController.text),
        dateDebut: _parseDate(_dateDebutController.text),
        dateFin: _parseDate(_dateFinController.text),
        montantMensuel: double.parse(_montantMensuelController.text),
        prixAchat: double.parse(_prixAchatController.text),
        nombrePaiements: int.parse(_nombrePaiementsController.text),
        paiementsEffectues: int.parse(_paiementsEffectuesController.text),
      );

      await DetteService().sauvegarderParametresDette(detteModifiee);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres sauvegardés avec succès')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
        );
      }
    }
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }

  @override
  void dispose() {
    _tauxController.dispose();
    _dateDebutController.dispose();
    _dateFinController.dispose();
    _montantMensuelController.dispose();
    _prixAchatController.dispose();
    _nombrePaiementsController.dispose();
    _paiementsEffectuesController.dispose();
    _simulateurTauxController.dispose();
    _simulateurPaiementController.dispose();
    _simulateurPrincipalController.dispose();
    _simulateurDureeController.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BandeauBienvenue extends StatefulWidget {
  const BandeauBienvenue({super.key});

  @override
  State<BandeauBienvenue> createState() => _BandeauBienvenueState();
}

class _BandeauBienvenueState extends State<BandeauBienvenue> {
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    // Faire disparaître le bandeau automatiquement après 5 secondes
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  void _fermerBandeau() {
    setState(() {
      _isVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final user = snapshot.data!;
        final displayName = user.displayName ?? 'Utilisateur';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image de Toutie (fixe, fond transparent)
              Image.asset(
                'assets/images/toutie.png',
                width: 50,
                height: 50,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              // Texte de bienvenue (s'ajuste à la longueur)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour $displayName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18191A),
                      ),
                    ),
                    const Text(
                      'Toutie te souhaite la bienvenue !',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              // Bouton pour fermer le bandeau
              IconButton(
                onPressed: _fermerBandeau,
                icon: const Icon(
                  Icons.close,
                  color: Color(0xFF666666),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:toutie_budget/pages/page_comptes_reorder.dart';
import 'package:toutie_budget/pages/page_login.dart';
import 'package:toutie_budget/services/firebase_service.dart';
import 'package:toutie_budget/services/theme_service.dart';

import 'package:toutie_budget/services/dette_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'models/categorie.dart';
import 'pages/page_budget.dart';
import 'pages/page_statistiques.dart';
import 'pages/page_set_objectif.dart';
import 'pages/page_ajout_transaction.dart';
import 'pages/page_pret_personnel.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'themes/dropdown_theme_extension.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('fr_CA', null);

  // Initialiser le service de thème
  final themeService = ThemeService();
  await themeService.loadTheme();

  runApp(MyApp(themeService: themeService));
}

class MyApp extends StatelessWidget {
  final ThemeService themeService;

  const MyApp({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: themeService,
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Toutie Budget',
            theme: themeService.getTheme().copyWith(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF18191A), // Noir doux
              colorScheme: ColorScheme.dark(
                primary: themeService.primaryColor,
                secondary: themeService.primaryColor,
                surface: const Color(0xFF232526),
              ),
              cardTheme: CardThemeData(
                color: const Color(0xFF232526),
                elevation: 2,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                margin: const EdgeInsets.all(8),
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: const Color(0xFF18191A),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: const Color(0xFF18191A),
                selectedItemColor: themeService.primaryColor,
                unselectedItemColor: Colors.white70,
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: themeService.primaryColor,
                foregroundColor: Colors.white,
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.white),
                bodyMedium: TextStyle(color: Colors.white70),
              ),
              // Thème pour les nouveaux DropdownMenu
              dropdownMenuTheme: DropdownMenuThemeData(
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStateProperty.all(
                    Color.lerp(const Color(0xFF232526), Colors.black, 0.15) ??
                        const Color(0xFF232526),
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              // Extensions pour supporter tous les types de dropdowns
              extensions: <ThemeExtension<dynamic>>[
                DropdownThemeExtension(
                  dropdownColor:
                      Color.lerp(const Color(0xFF232526), Colors.black, 0.15) ??
                          const Color(0xFF232526),
                ),
              ],
            ),
            home: StreamBuilder<User?>(
              stream: FirebaseService().authStateChanges,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasData) {
                  return const MyHomePage();
                }
                return const PageLogin();
              },
            ),
            locale: const Locale('fr', 'CA'),
            supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'US')],
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            onGenerateRoute: (settings) {
              if (settings.name == '/set_objectif') {
                final args = settings.arguments as Map<String, dynamic>;
                final enveloppe = args['enveloppe'] as Enveloppe;
                final categorie = args['categorie'] as Categorie;
                return MaterialPageRoute(
                  builder: (context) => PageSetObjectif(
                    enveloppe: enveloppe,
                    categorie: categorie,
                  ),
                );
              }
              return null;
            },
            routes: {
              '/pret-personnel': (context) => const PagePretPersonnel(),
              // ...autres routes si besoin...
            },
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  int? _lastIndexBeforeAjout;

  // Exemple de liste de comptes fictive (à remplacer par votre logique réelle)
  final List<String> comptesExistants = [
    'Compte Courant',
    'Épargne',
    'Carte de Crédit',
    'Wealthsimple',
  ];

  static const _pageBudget = PageBudget();
  static const _PageComptesReorder = PageComptesReorder();
  static const _pageStatistiques = PageStatistiques();

  @override
  void initState() {
    super.initState();

    // Mettre à jour les dettes existantes pour ajouter le champ estManuelle
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        DetteService().mettreAJourDettesExistantes();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      _pageBudget,
      _PageComptesReorder,
      EcranAjoutTransactionRefactored(
        comptesExistants: comptesExistants,
        onTransactionSaved: () {
          setState(() {
            _selectedIndex = _lastIndexBeforeAjout ?? 0;
          });
        },
      ),
      _pageStatistiques,
    ];

    void onItemTapped(int index) {
      if (index == 2) {
        // On sauvegarde l'index courant avant d'aller sur l'ajout
        _lastIndexBeforeAjout = _selectedIndex;
      }
      setState(() {
        _selectedIndex = index;
      });
    }

    return Scaffold(
      // Suppression de l'AppBar pour un affichage sans barre supérieure
      body: pages[_selectedIndex],
      bottomNavigationBar: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Opacity(
                  opacity: _selectedIndex == 0 ? 1.0 : 0.6,
                  child: SvgPicture.asset(
                    'assets/icons/budget.svg',
                    width: _selectedIndex == 0 ? 36 : 32,
                    height: _selectedIndex == 0 ? 36 : 32,
                    colorFilter: ColorFilter.mode(
                      themeService.primaryColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Opacity(
                  opacity: _selectedIndex == 1 ? 1.0 : 0.6,
                  child: SvgPicture.asset(
                    'assets/icons/compte.svg',
                    width: _selectedIndex == 1 ? 36 : 32,
                    height: _selectedIndex == 1 ? 36 : 32,
                    colorFilter: ColorFilter.mode(
                      themeService.primaryColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Opacity(
                  opacity: _selectedIndex == 2 ? 1.0 : 0.6,
                  child: SvgPicture.asset(
                    'assets/icons/ajout_transaction.svg',
                    width: _selectedIndex == 2 ? 36 : 32,
                    height: _selectedIndex == 2 ? 36 : 32,
                    colorFilter: ColorFilter.mode(
                      themeService.primaryColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Opacity(
                  opacity: _selectedIndex == 3 ? 1.0 : 0.6,
                  child: Icon(
                    Icons.bar_chart,
                    color: themeService.primaryColor,
                    size: _selectedIndex == 3 ? 36 : 32,
                  ),
                ),
                label: '',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: themeService.primaryColor,
            onTap: onItemTapped,
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:toutie_budget/pages/page_login.dart';
import 'package:toutie_budget/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/categorie.dart';
import 'pages/page_budget.dart';
import 'pages/page_statistiques.dart';
import 'pages/page_comptes.dart';
import 'pages/page_set_objectif.dart';
import 'pages/page_ajout_transaction.dart';
import 'pages/page_pret_personnel.dart';
import 'package:flutter_svg/flutter_svg.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('fr_CA', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF18191A), // Noir doux
        colorScheme: ColorScheme.dark(
          primary: Color(0xFFB71C1C), // Rouge foncé
          secondary: Color(0xFFD32F2F), // Rouge foncé accent
          surface: const Color(0xFF232526),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF18191A),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF18191A),
          selectedItemColor: Color(0xFFB71C1C), // Rouge foncé
          unselectedItemColor: Colors.white70,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFB71C1C), // Rouge foncé
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const MyHomePage();
          }
          return const PageLogin();
        },
      ),
      locale: const Locale('fr', 'CA'),
      supportedLocales: const [
        Locale('fr', 'CA'),
        Locale('en', 'US'),
      ],
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
            builder: (context) => PageSetObjectif(enveloppe: enveloppe, categorie: categorie),
          );
        }
        return null;
      },
      routes: {
        '/pret-personnel': (context) => const PagePretPersonnel(),
        // ...autres routes si besoin...
      },
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
  static const _pageComptes = PageComptes();
  static const _pageStatistiques = PageStatistiques();

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = <Widget>[
      _pageBudget,
      _pageComptes,
      EcranAjoutTransaction(
        comptesExistants: comptesExistants,
        onTransactionSaved: () {
          setState(() {
            _selectedIndex = _lastIndexBeforeAjout ?? 0;
          });
        },
      ),
      _pageStatistiques,
    ];

    void _onItemTapped(int index) {
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
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
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
                  Colors.red,
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
                  Colors.red,
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
                  Colors.red,
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
                color: Colors.red,
                size: _selectedIndex == 3 ? 36 : 32,
              ),
            ),
            label: '',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }
}

// debugPaintSizeEnabled = true; // Pour le debug visuel, à désactiver en prod

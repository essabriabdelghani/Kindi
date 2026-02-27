import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import '../l10n/app_localizations.dart';
import 'services/locale_service.dart';
import 'services/db_service.dart';
import 'pages/connexion_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await DBService.database;
  await DBService.insertChecklistQuestions();
  runApp(const MyApp());
}

// ════════════════════════════════════════════════════════════
// MyApp — avec locale dynamique
// ════════════════════════════════════════════════════════════
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // ✅ Clé globale pour changer la locale depuis n'importe quelle page
  static _MyAppState? _instance;

  static void setLocale(BuildContext context, Locale locale) {
    _instance?.changeLocale(locale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('fr'); // défaut
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    MyApp._instance = this;
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final saved = await LocaleService.loadLocale();
    setState(() {
      _locale = saved;
      _loaded = true;
    });
  }

  void changeLocale(Locale locale) {
    setState(() => _locale = locale);
    LocaleService.saveLocale(locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator(color: Colors.orange)),
        ),
      );
    }

    return MaterialApp(
      title: 'KINDI',
      locale: _locale,
      supportedLocales: const [Locale('fr'), Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // RTL automatique pour l'arabe
      builder: (context, child) {
        return Directionality(
          textDirection: _locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child!,
        );
      },
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      home: const ConnexionPage(),
    );
  }
}

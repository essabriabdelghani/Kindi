import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Ces imports ne sont pas utilisés dans main.dart :
// import 'package:kindi/pages/InscriptionPage.dart';
// import 'package:kindi/pages/ProfHomePage.dart';
// import 'package:kindi/pages/MesClassesPage.dart';
// import 'package:kindi/pages/ProfilEnfantPage.dart';
// import 'package:kindi/pages/FormulaireObservation.dart';

import '../l10n/app_localizations.dart';
import 'package:kindi/pages/connexion_page.dart';
import 'package:kindi/pages/main_layout.dart';
import 'package:kindi/models/teachers.dart';
import '../services/db_service.dart';
import '../services/session_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. SQLite
  if (!kIsWeb) {
    await DBService.database;
    await DBService.insertChecklistQuestions();
  }

  // 3. ✅ NOUVEAU : essayer de restaurer la session
  final savedUser = await SessionService.restoreSession();

  runApp(MyApp(savedUser: savedUser));
}

class MyApp extends StatelessWidget {
  final Teacher? savedUser; // ✅ null = aller à ConnexionPage
  const MyApp({super.key, this.savedUser});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kindi',
      supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('fr'),
      // ✅ Si session restaurée → MainLayout, sinon → ConnexionPage
      home: savedUser != null ? MainLayout(user: savedUser!) : ConnexionPage(),
    );
  }
}

// ============================================================
// locale_service.dart — lib/services/locale_service.dart
//
// Gère la langue sélectionnée par l'utilisateur
// Sauvegarde dans SharedPreferences
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static const _key = 'selected_locale';

  // Langues supportées
  static const List<Map<String, dynamic>> supportedLanguages = [
    {'locale': Locale('fr'), 'name': 'Français', 'flag': '🇫🇷', 'code': 'fr'},
    {'locale': Locale('ar'), 'name': 'العربية', 'flag': '🇲🇦', 'code': 'ar'},
    {'locale': Locale('en'), 'name': 'English', 'flag': '🇬🇧', 'code': 'en'},
  ];

  // Sauvegarder la langue choisie
  static Future<void> saveLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, languageCode);
  }

  // Charger la langue sauvegardée (fr par défaut)
  static Future<Locale> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'fr';
    return Locale(code);
  }

  // Nom lisible de la langue
  static String getLanguageName(String code) {
    final lang = supportedLanguages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => supportedLanguages.first,
    );
    return '${lang['flag']} ${lang['name']}';
  }
}

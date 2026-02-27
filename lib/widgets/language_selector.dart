// ============================================================
// language_selector.dart — lib/widgets/language_selector.dart
//
// Widget sélecteur de langue — utilisable partout dans l'app
// ============================================================

import 'package:flutter/material.dart';
import '../services/locale_service.dart';
import '../main.dart';

class LanguageSelector extends StatelessWidget {
  final bool showLabel;
  const LanguageSelector({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final currentCode = Localizations.localeOf(context).languageCode;

    return PopupMenuButton<String>(
      tooltip: "Changer la langue",
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language, color: Colors.white),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              currentCode.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      onSelected: (code) async {
        final locale = Locale(code);
        await LocaleService.saveLocale(code);
        if (context.mounted) {
          MyApp.setLocale(context, locale);
        }
      },
      itemBuilder: (_) => LocaleService.supportedLanguages.map((lang) {
        final isSelected = lang['code'] == currentCode;
        return PopupMenuItem<String>(
          value: lang['code'] as String,
          child: Row(
            children: [
              Text(
                lang['flag'] as String,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 12),
              Text(
                lang['name'] as String,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.orange : null,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                const Icon(Icons.check, color: Colors.orange, size: 18),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Version bottom sheet (pour paramètres/profil) ───────────
class LanguageSelectorSheet extends StatelessWidget {
  const LanguageSelectorSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const LanguageSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCode = Localizations.localeOf(context).languageCode;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            "Langue / Language / اللغة",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          ...LocaleService.supportedLanguages.map((lang) {
            final isSelected = lang['code'] == currentCode;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final code = lang['code'] as String;
                final locale = Locale(code);
                await LocaleService.saveLocale(code);
                if (context.mounted) {
                  MyApp.setLocale(context, locale);
                  Navigator.pop(context);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.orange
                        : Colors.grey.withOpacity(0.2),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      lang['flag'] as String,
                      style: const TextStyle(fontSize: 26),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang['name'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? Colors.orange : null,
                          ),
                        ),
                        Text(
                          lang['code'] as String == 'fr'
                              ? 'Français'
                              : lang['code'] == 'ar'
                              ? 'Arabic'
                              : 'English',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

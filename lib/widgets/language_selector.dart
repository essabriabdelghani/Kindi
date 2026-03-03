import 'package:flutter/material.dart';
import '../services/locale_service.dart';

class LanguageSelector extends StatelessWidget {
  final Color iconColor;
  const LanguageSelector({super.key, this.iconColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    final currentCode = Localizations.localeOf(context).languageCode;

    return PopupMenuButton<String>(
      tooltip: "Langue",
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.language, color: iconColor),
          const SizedBox(width: 4),
          Text(
            currentCode.toUpperCase(),
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      onSelected: (code) async {
        await LocaleService.saveLocale(code);
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

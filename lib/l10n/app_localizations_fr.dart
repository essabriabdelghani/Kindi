// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'KINDI';

  @override
  String get appSubtitle => 'Gestion et suivi des enfants';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'votre.email@exemple.com';

  @override
  String get password => 'Mot de passe';

  @override
  String get passwordHint => '••••••••';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'S’inscrire';

  @override
  String get or => 'ou';

  @override
  String get noAccount => 'Vous n\'avez pas de compte ?';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get alreadyHaveAccount => 'Vous avez déjà un compte ? Se connecter';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get phone => 'Téléphone';

  @override
  String get schoolName => 'Nom de l\'école';

  @override
  String get schoolCity => 'Ville';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get invalidCredentials => 'Email ou mot de passe incorrect';

  @override
  String get fillAllFields => 'Veuillez remplir tous les champs';

  @override
  String get accountCreated => 'Compte créé avec succès';

  @override
  String get emailAlreadyUsed => 'Cette adresse e-mail est déjà utilisée';

  @override
  String get passwordsNotMatch => 'Les mots de passe ne correspondent pas';
}

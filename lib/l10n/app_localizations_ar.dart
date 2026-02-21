// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'كيندي';

  @override
  String get appSubtitle => 'تدبير وتتبع الأطفال';

  @override
  String get welcome => 'مرحبا';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get emailHint => 'email@example.com';

  @override
  String get password => 'كلمة المرور';

  @override
  String get passwordHint => '••••••••';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get or => 'أو';

  @override
  String get noAccount => 'ليس لديك حساب؟';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟ تسجيل الدخول';

  @override
  String get firstName => 'الاسم الشخصي';

  @override
  String get lastName => 'الاسم العائلي';

  @override
  String get phone => 'رقم الهاتف';

  @override
  String get schoolName => 'اسم المؤسسة';

  @override
  String get schoolCity => 'المدينة';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get invalidCredentials => 'البريد الإلكتروني أو كلمة المرور غير صحيحة';

  @override
  String get fillAllFields => 'يرجى ملء جميع الحقول';

  @override
  String get accountCreated => 'تم إنشاء الحساب بنجاح';

  @override
  String get emailAlreadyUsed => 'هذا البريد الإلكتروني مستخدم بالفعل';

  @override
  String get passwordsNotMatch => 'كلمتا المرور غير متطابقتين';
}

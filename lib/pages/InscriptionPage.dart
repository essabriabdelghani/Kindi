import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/teachers.dart';
import '../controllers/auth_controller.dart';

class InscriptionPage extends StatefulWidget {
  const InscriptionPage({super.key});

  @override
  State<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<InscriptionPage> {
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _loading = false;

  // ── Étape : 1=formulaire  2=attente confirmation email ──
  int _step = 1;

  // Données du teacher gardées en mémoire entre étapes
  Teacher? _pendingTeacher;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _schoolCtrl.dispose();
    _cityCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════
  // ÉTAPE 1 : Envoyer email de vérification
  // ════════════════════════════════════════════════════════
  Future<void> _sendVerification(AppLocalizations t) async {
    // Validation basique
    if (_firstNameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.trim().isEmpty) {
      _showSnack(
        "Veuillez remplir tous les champs obligatoires",
        Colors.orange,
      );
      return;
    }

    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      _showSnack(t.passwordsNotMatch, Colors.red);
      return;
    }

    if (_passwordCtrl.text.length < 6) {
      _showSnack("Mot de passe trop court (min 6 caractères)", Colors.red);
      return;
    }

    setState(() => _loading = true);

    // Garder les données du teacher en mémoire
    _pendingTeacher = Teacher(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      schoolName: _schoolCtrl.text.trim(),
      schoolCity: _cityCtrl.text.trim(),
      role: 'teacher',
      passwordHash: _passwordCtrl.text.trim(), // clair, sera hashé plus tard
    );

    // Envoyer email de vérification (compte Firebase temporaire)
    final error = await AuthController.sendVerificationBeforeRegister(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error == 'email_already_verified') {
      _showSnack("Email déjà utilisé", Colors.red);
      return;
    }

    if (error != null) {
      _showSnack(error, Colors.red);
      return;
    }

    // ✅ Email envoyé → passer à l'étape 2
    setState(() => _step = 2);
  }

  // ════════════════════════════════════════════════════════
  // ÉTAPE 2 : User a cliqué le lien → finaliser l'inscription
  // ════════════════════════════════════════════════════════
  Future<void> _completeRegistration() async {
    if (_pendingTeacher == null) return;

    setState(() => _loading = true);

    final result = await AuthController.completeRegistrationAfterVerification(
      _pendingTeacher!,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result == RegisterResult.success) {
      _showSnack("Compte créé avec succès ✅", Colors.green);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.pop(context); // retour connexion
    } else if (result == RegisterResult.emailNotVerified) {
      _showSnack(
        "Email pas encore confirmé — vérifiez votre boîte mail",
        Colors.orange,
      );
    } else {
      _showSnack(result.message, Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final deviceWidth = MediaQuery.of(context).size.width;
    final cardWidth = deviceWidth > 600 ? 450.0 : deviceWidth * 0.95;

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Container(
            width: cardWidth,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _step == 1 ? _buildStep1(t) : _buildStep2(),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // VUE ÉTAPE 1 : Formulaire inscription
  // ════════════════════════════════════════════════════════
  Widget _buildStep1(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Logo
        const Column(
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: Colors.orange,
              child: Icon(Icons.group, color: Colors.white, size: 38),
            ),
            SizedBox(height: 10),
            Text(
              "KINDI",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Text(
          t.createAccount,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 25),

        _input(t.firstName, _firstNameCtrl),
        _input(t.lastName, _lastNameCtrl),
        _input(t.email, _emailCtrl, keyboard: TextInputType.emailAddress),
        _input(t.phone, _phoneCtrl, keyboard: TextInputType.phone),
        _input(t.schoolName, _schoolCtrl),
        _input(t.schoolCity, _cityCtrl),

        _input(
          t.password,
          _passwordCtrl,
          obscure: !_showPassword,
          suffix: IconButton(
            icon: Icon(
              _showPassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.orange,
            ),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),

        _input(
          t.confirmPassword,
          _confirmPasswordCtrl,
          obscure: !_showConfirmPassword,
          suffix: IconButton(
            icon: Icon(
              _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.orange,
            ),
            onPressed: () =>
                setState(() => _showConfirmPassword = !_showConfirmPassword),
          ),
        ),

        const SizedBox(height: 25),

        // Bouton envoyer vérification
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.email, color: Colors.white),
            label: Text(
              _loading ? "Envoi en cours..." : "Vérifier mon email",
              style: const TextStyle(fontSize: 17, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              disabledBackgroundColor: Colors.orange.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: _loading ? null : () => _sendVerification(t),
          ),
        ),
        const SizedBox(height: 15),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.alreadyHaveAccount, textAlign: TextAlign.center),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  // VUE ÉTAPE 2 : Attente confirmation email
  // ════════════════════════════════════════════════════════
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icône email
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread,
              color: Colors.orange,
              size: 50,
            ),
          ),
        ),

        const Text(
          "Confirmez votre email",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),

        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(height: 8),
              Text(
                "Un email de vérification a été envoyé à :\n${_emailCtrl.text.trim()}",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              const Text(
                "1️⃣  Ouvrez votre boîte mail\n"
                "2️⃣  Cliquez sur le lien de confirmation\n"
                "3️⃣  Revenez ici et appuyez sur le bouton",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),

        // ✅ Bouton principal : finaliser inscription
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle, color: Colors.white),
            label: Text(
              _loading ? "Vérification..." : "J'ai confirmé mon email ✅",
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: _loading ? null : _completeRegistration,
          ),
        ),
        const SizedBox(height: 12),

        // Renvoyer email
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh, color: Colors.orange),
          label: const Text(
            "Renvoyer l'email",
            style: TextStyle(color: Colors.orange),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.orange),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _loading
              ? null
              : () async {
                  setState(() => _loading = true);
                  await AuthController.resendVerificationEmail(
                    email: _emailCtrl.text.trim(),
                    password: _passwordCtrl.text.trim(),
                  );
                  if (!mounted) return;
                  setState(() => _loading = false);
                  _showSnack("Email renvoyé ✅", Colors.green);
                },
        ),
        const SizedBox(height: 12),

        // Retour formulaire
        TextButton(
          onPressed: () => setState(() => _step = 1),
          child: const Text(
            "← Modifier mes informations",
            style: TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  // Helper champ texte
  // ════════════════════════════════════════════════════════
  Widget _input(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        enabled: !_loading,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.person, color: Colors.orange),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }
}

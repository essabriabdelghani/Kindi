import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../controllers/auth_controller.dart';
import 'InscriptionPage.dart';
import '../utils/security_helper.dart';
import 'main_layout.dart';
import '../services/session_service.dart';

class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
  bool _showPassword = false;
  bool _loading = false;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login(AppLocalizations t) async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.fillAllFields),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final passwordHash = SecurityHelper.hashPassword(password);

    final result = await AuthController.login(
      email: email,
      passwordHash: passwordHash,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      SessionService.login(result.teacher!);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainLayout(user: result.teacher!)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? t.invalidCredentials),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final deviceWidth = MediaQuery.of(context).size.width;
    final cardWidth = deviceWidth > 600 ? 450.0 : deviceWidth * 0.9;

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // LOGO
              const Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.group, color: Colors.white, size: 40),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'KINDI',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // CARD
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        t.welcome,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // EMAIL
                    Text(t.email),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_loading,
                      decoration: _inputStyle(
                        hint: t.emailHint,
                        icon: Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // PASSWORD
                    Text(t.password),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: !_showPassword,
                      enabled: !_loading,
                      onSubmitted: (_) => _login(t),
                      decoration: _inputStyle(
                        hint: t.passwordHint,
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.orange,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // MOT DE PASSE OUBLIÉ
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fonctionnalité à venir'),
                            ),
                          );
                        },
                        child: Text(
                          t.forgotPassword,
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // BOUTON CONNEXION
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : () => _login(t),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          disabledBackgroundColor: Colors.orange.withOpacity(
                            0.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.login, color: Colors.white),
                                  const SizedBox(width: 10),
                                  Text(
                                    t.signIn,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // CRÉER UN COMPTE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.noAccount),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const InscriptionPage(),
                                  ),
                                ),
                          child: Text(
                            t.createAccount,
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputStyle({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.orange),
      suffixIcon: suffix,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
    );
  }
}

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
  final _formKey = GlobalKey<FormState>();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _loading = false;

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

  Future<void> _submit(AppLocalizations t) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final teacher = Teacher(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      schoolName: _schoolCtrl.text.trim(),
      schoolCity: _cityCtrl.text.trim(),
      role: 'teacher',
      passwordHash: _passwordCtrl.text.trim(),
    );

    final result = await AuthController.register(teacher);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result == RegisterResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.accountCreated),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  Text(
                    t.createAccount,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),

                  _field(
                    label: t.firstName,
                    ctrl: _firstNameCtrl,
                    icon: Icons.person,
                    validator: (v) => v!.trim().isEmpty ? 'Champ requis' : null,
                  ),
                  _field(
                    label: t.lastName,
                    ctrl: _lastNameCtrl,
                    icon: Icons.person_outline,
                  ),
                  _field(
                    label: t.email,
                    ctrl: _emailCtrl,
                    icon: Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                    validator: (v) {
                      if (v!.trim().isEmpty) return 'Champ requis';
                      if (!v.contains('@') || !v.contains('.'))
                        return 'Email invalide';
                      return null;
                    },
                  ),
                  _field(
                    label: t.phone,
                    ctrl: _phoneCtrl,
                    icon: Icons.phone,
                    keyboard: TextInputType.phone,
                  ),
                  _field(
                    label: t.schoolName,
                    ctrl: _schoolCtrl,
                    icon: Icons.school,
                    validator: (v) => v!.trim().isEmpty ? 'Champ requis' : null,
                  ),
                  _field(
                    label: t.schoolCity,
                    ctrl: _cityCtrl,
                    icon: Icons.location_city,
                    validator: (v) => v!.trim().isEmpty ? 'Champ requis' : null,
                  ),

                  // PASSWORD
                  _field(
                    label: t.password,
                    ctrl: _passwordCtrl,
                    icon: Icons.lock_outline,
                    obscure: !_showPassword,
                    validator: (v) {
                      if (v!.isEmpty) return 'Champ requis';
                      if (v.length < 6) return '6 caractères minimum';
                      return null;
                    },
                    suffix: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.orange,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),

                  // CONFIRM PASSWORD
                  _field(
                    label: t.confirmPassword,
                    ctrl: _confirmPasswordCtrl,
                    icon: Icons.lock,
                    obscure: !_showConfirmPassword,
                    validator: (v) =>
                        v != _passwordCtrl.text ? t.passwordsNotMatch : null,
                    suffix: IconButton(
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.orange,
                      ),
                      onPressed: () => setState(
                        () => _showConfirmPassword = !_showConfirmPassword,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // BOUTON
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : () => _submit(t),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        disabledBackgroundColor: Colors.orange.withOpacity(0.5),
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
                          : Text(
                              t.signUp,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: Text(
                      t.alreadyHaveAccount,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboard,
        validator: validator,
        enabled: !_loading,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.orange),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          errorStyle: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}

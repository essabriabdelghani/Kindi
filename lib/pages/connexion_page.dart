import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../controllers/auth_controller.dart';
import 'InscriptionPage.dart';
import '../utils/security_helper.dart';
import 'main_layout.dart';
import '../services/session_service.dart';
import 'forgot_password_page.dart'; // ✅ AJOUTÉ

class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
  bool showPassword = false;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    double deviceWidth = MediaQuery.of(context).size.width;
    double cardWidth = deviceWidth > 600 ? 450 : deviceWidth * 0.9;

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // LOGO
              Column(
                children: const [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.group, color: Colors.white, size: 40),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "KINDI",
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
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: inputStyle(
                        hint: t.emailHint,
                        icon: Icons.email_outlined,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // PASSWORD
                    Text(t.password),
                    const SizedBox(height: 5),
                    TextField(
                      controller: passwordController,
                      obscureText: !showPassword,
                      decoration: inputStyle(
                        hint: t.passwordHint,
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            showPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.orange,
                          ),
                          onPressed: () {
                            setState(() {
                              showPassword = !showPassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordPage(),
                          ),
                        ),
                        child: Text(
                          t.forgotPassword,
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // BUTTON (frontend only)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final email = emailController.text.trim();
                          final password = passwordController.text.trim();

                          if (email.isEmpty || password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t.fillAllFields)),
                            );
                            return;
                          }
                          final passwordHash = SecurityHelper.hashPassword(
                            password,
                          );
                          final result = await AuthController.login(
                            email: email,
                            password: password, // ← EN CLAIR pour Firebase
                            passwordHash: passwordHash, // ← hash pour SQLite
                          );

                          if (result.success) {
                            SessionService.login(result.teacher!);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MainLayout(user: result.teacher!),
                              ),
                            );
                          } else if (result.error == 'email_not_verified') {
                            // ✅ Email existe mais pas encore vérifié
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(
                                      Icons.mark_email_unread,
                                      color: Colors.orange,
                                    ),
                                    SizedBox(width: 10),
                                    Text("Email non confirmé"),
                                  ],
                                ),
                                content: const Text(
                                  "Votre email n'est pas encore confirmé.\n\n"
                                  "Vérifiez votre boîte mail et cliquez sur le lien d'activation.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Fermer"),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                    ),
                                    icon: const Icon(
                                      Icons.send,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      "Renvoyer l'email",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await AuthController.resendVerificationEmail(
                                        email: email,
                                        password: password,
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Email renvoyé ✅ Vérifiez votre boîte",
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // Email/password incorrect
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.error ?? t.invalidCredentials,
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login, color: Colors.white),
                            SizedBox(width: 10),
                            Text(t.signIn, style: TextStyle(fontSize: 18)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // CREATE ACCOUNT
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.noAccount),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const InscriptionPage(),
                              ),
                            );
                          },
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
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration inputStyle({
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

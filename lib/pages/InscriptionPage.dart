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
  bool showPassword = false;
  bool showConfirmPassword = false;

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final schoolController = TextEditingController();
  final cityController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    double deviceWidth = MediaQuery.of(context).size.width;
    double cardWidth = deviceWidth > 600 ? 450 : deviceWidth * 0.95;

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      body: Center(
        child: SingleChildScrollView(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LOGO
                Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.group, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "KINDI",
                      style: const TextStyle(
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

                _input(t.firstName, firstNameController),
                _input(t.lastName, lastNameController),
                _input(
                  t.email,
                  emailController,
                  keyboard: TextInputType.emailAddress,
                ),
                _input(t.phone, phoneController, keyboard: TextInputType.phone),
                _input(t.schoolName, schoolController),
                _input(t.schoolCity, cityController),

                _input(
                  t.password,
                  passwordController,
                  obscure: !showPassword,
                  suffix: IconButton(
                    icon: Icon(
                      showPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.orange,
                    ),
                    onPressed: () {
                      setState(() {
                        showPassword = !showPassword;
                      });
                    },
                  ),
                ),

                _input(
                  t.confirmPassword,
                  confirmPasswordController,
                  obscure: !showConfirmPassword,
                  suffix: IconButton(
                    icon: Icon(
                      showConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.orange,
                    ),
                    onPressed: () {
                      setState(() {
                        showConfirmPassword = !showConfirmPassword;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (passwordController.text !=
                          confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.passwordsNotMatch)),
                        );
                        return;
                      }

                      final teacher = Teacher(
                        firstName: firstNameController.text.trim(),
                        lastName: lastNameController.text.trim(),
                        email: emailController.text.trim(),
                        phoneNumber: phoneController.text.trim(),
                        schoolName: schoolController.text.trim(),
                        schoolCity: cityController.text.trim(),
                        role: 'teacher',
                        passwordHash: passwordController.text
                            .trim(), // <-- sans hash
                      );

                      final result = await AuthController.register(teacher);

                      if (result == RegisterResult.success) {
                        // ✅ Compte créé → demander de vérifier email
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(
                                  Icons.mark_email_read,
                                  color: Colors.green,
                                  size: 28,
                                ),
                                SizedBox(width: 10),
                                Text("Compte créé ✅"),
                              ],
                            ),
                            content: const Text(
                              "Un email de confirmation a été envoyé."
                              "Vérifiez votre boîte mail et cliquez sur "
                              "le lien pour activer votre compte."
                              "⚠️ Sans confirmation, vous ne pourrez pas vous connecter.",
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                onPressed: () {
                                  Navigator.pop(context); // fermer dialog
                                  Navigator.pop(context); // retour connexion
                                },
                                child: const Text(
                                  "J'ai compris",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.message),
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
                    child: Text(t.signUp, style: const TextStyle(fontSize: 18)),
                  ),
                ),

                const SizedBox(height: 15),

                TextButton(
                  onPressed: () => Navigator.pop(context),
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
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
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

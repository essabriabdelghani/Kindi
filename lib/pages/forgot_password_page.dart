// ============================================================
// forgot_password_page.dart — lib/pages/forgot_password_page.dart
//
// Page "Mot de passe oublié"
// Envoie un email de réinitialisation via Firebase Auth
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _emailSent = false; // ✅ pour afficher l'écran de confirmation

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez entrer votre email"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email invalide"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _emailSent = true; // ✅ afficher l'écran de succès
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      String message;
      switch (e.code) {
        case 'user-not-found':
          // ✅ Par sécurité, on affiche quand même le succès
          // pour ne pas révéler si l'email existe ou non
          setState(() => _emailSent = true);
          return;
        case 'invalid-email':
          message = "Format email invalide";
          break;
        case 'too-many-requests':
          message = "Trop de tentatives. Réessayez plus tard.";
          break;
        default:
          message = "Erreur : ${e.message}";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur réseau. Vérifiez votre connexion."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width > 600 ? 450.0 : width * 0.9;

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text("Mot de passe oublié"),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: cardWidth,
            child: _emailSent ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
    );
  }

  // ── Vue formulaire ─────────────────────────────────────
  Widget _buildFormView() {
    return Container(
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
          // Icône
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.orange,
              child: Icon(Icons.lock_reset, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 20),

          // Titre
          const Text(
            "Réinitialiser le mot de passe",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Description
          const Text(
            "Entrez votre email et nous vous enverrons un lien pour réinitialiser votre mot de passe.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 30),

          // Champ email
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            enabled: !_loading,
            decoration: InputDecoration(
              labelText: "Votre email",
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: Colors.orange,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onSubmitted: (_) => _sendResetEmail(),
          ),
          const SizedBox(height: 25),

          // Bouton envoyer
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
                  : const Icon(Icons.send, color: Colors.white),
              label: Text(
                _loading ? "Envoi en cours..." : "Envoyer le lien",
                style: const TextStyle(fontSize: 17, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                disabledBackgroundColor: Colors.orange.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _loading ? null : _sendResetEmail,
            ),
          ),
          const SizedBox(height: 15),

          // Retour connexion
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Retour à la connexion",
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  // ── Vue succès après envoi ─────────────────────────────
  Widget _buildSuccessView() {
    return Container(
      padding: const EdgeInsets.all(30),
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
        children: [
          // Icône succès
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read,
              color: Colors.green,
              size: 50,
            ),
          ),
          const SizedBox(height: 25),

          const Text(
            "Email envoyé ! ✅",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          Text(
            "Un lien de réinitialisation a été envoyé à :\n${_emailCtrl.text.trim()}",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: 10),

          const Text(
            "Vérifiez votre boîte mail (et les spams).\nCliquez le lien pour créer un nouveau mot de passe.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black38),
          ),
          const SizedBox(height: 30),

          // Renvoyer l'email
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => setState(() => _emailSent = false),
          ),
          const SizedBox(height: 15),

          // Retour connexion
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Retour à la connexion",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// lib/src/presentation/pages/auth/login/login_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // ← Ajouter cet import
import 'package:ozn/src/core/constants/app_constants.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                onPressed: () => context.go('/onboarding'), // ← Corriger la navigation
                icon: const Icon(Icons.arrow_back),
              ),

              const SizedBox(height: 20),

              // Title
              const Text('Content de vous revoir !', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Connectez-vous à votre compte OZN', style: TextStyle(fontSize: 16, color: Colors.grey)),

              const SizedBox(height: 40),

              // Form
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Adresse email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () {}, child: const Text('Mot de passe oublié ?')),
              ),

              const SizedBox(height: 24),

              // Login button
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Se connecter'),
              ),

              const SizedBox(height: 16),

              // BOUTON DEV - Accès direct à l'accueil ← NOUVEAU
              ElevatedButton(
                onPressed: _goToHomeDirect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange, // Couleur distincte pour le dev
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.developer_mode, size: 20),
                    SizedBox(width: 8),
                    Text('Mode Développeur - Accéder à l\'accueil'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Divider
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('ou')),
                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 24),

              // Social buttons (simplifiés)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSocialButton('G', () {}),
                  _buildSocialButton('A', () {}),
                  _buildSocialButton('f', () {}),
                ],
              ),

              const SizedBox(height: 32),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pas de compte ? '),
                  TextButton(
                    onPressed: () => context.go('/register'), // ← Corriger la navigation
                    child: const Text('S\'inscrire'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(String text, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(backgroundColor: Colors.grey[100], minimumSize: const Size(60, 60)),
      icon: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir tous les champs')));
      return;
    }

    setState(() => _isLoading = true);

    // Simulation de connexion
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Redirection vers l'accueil
    context.go('/home');
  }

  // NOUVELLE MÉTHODE : Accès direct pour le développement
  void _goToHomeDirect() {
    // Aller directement à l'accueil sans authentification
    context.go('/home');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

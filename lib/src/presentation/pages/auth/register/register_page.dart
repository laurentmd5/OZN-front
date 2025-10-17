// lib/src/presentation/pages/auth/register/register_page.dart
import 'package:flutter/material.dart';
import 'package:ozn/src/core/constants/app_constants.dart';
import 'package:ozn/src/presentation/pages/home/home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  
  // Données du formulaire
  UserRole _selectedRole = UserRole.passenger;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();

  final List<Step> _steps = [
    const Step(
      title: Text('Rôle'),
      content: SizedBox(), // Sera rempli dynamiquement
    ),
    const Step(
      title: Text('Informations'),
      content: SizedBox(),
    ),
    const Step(
      title: Text('Sécurité'),
      content: SizedBox(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _currentStep == 0 
              ? Navigator.pop(context)
              : setState(() => _currentStep--),
        ),
        title: const Text('Créer un compte'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _continue,
        onStepCancel: _cancel,
        steps: [
          // Étape 1: Rôle
          Step(
            title: const Text('Rôle'),
            content: Column(
              children: [
                _buildRoleOption(UserRole.passenger, 'Passager', 'Je cherche des courses'),
                const SizedBox(height: 16),
                _buildRoleOption(UserRole.driver, 'Conducteur', 'Je propose des courses'),
                const SizedBox(height: 16),
                _buildRoleOption(UserRole.both, 'Les deux', 'Je cherche et propose'),
              ],
            ),
          ),

          // Étape 2: Informations
          Step(
            title: const Text('Informations'),
            content: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'Prénom',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Étape 3: Sécurité
          Step(
            title: const Text('Sécurité'),
            content: Column(
              children: [
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.length < 6 ? '6 caractères minimum' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(value: true, onChanged: (value) {}),
                    const Expanded(
                      child: Text('J\'accepte les conditions d\'utilisation'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _currentStep == 2 ? _buildRegisterButton() : null,
    );
  }

  Widget _buildRoleOption(UserRole role, String title, String subtitle) {
    return Card(
      child: ListTile(
        leading: Radio<UserRole>(
          value: role,
          groupValue: _selectedRole,
          onChanged: (value) => setState(() => _selectedRole = value!),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: () => setState(() => _selectedRole = role),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF27AE60),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          ),
        ),
        child: const Text('Créer mon compte'),
      ),
    );
  }

  void _continue() {
    if (_currentStep == 1 && !_formKey.currentState!.validate()) {
      return;
    }

    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    }
  }

  void _cancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _register() async {
    // Simulation d'inscription
    await Future.delayed(const Duration(seconds: 2));
    
    // Redirection vers l'accueil
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
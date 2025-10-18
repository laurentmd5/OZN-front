// lib/src/presentation/pages/auth/onboarding/onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // ← AJOUTER CET IMPORT
import 'package:ozn/src/core/constants/app_constants.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'title': 'Solidarité à 500m',
      'description': 'Connectez-vous avec vos voisins pour des courses partagées',
      'emoji': '👥',
    },
    {'title': 'Écologique', 'description': 'Réduisez votre empreinte carbone ensemble', 'emoji': '🌱'},
    {'title': 'Sécurisé', 'description': 'Profils vérifiés et système de confiance', 'emoji': '🔒'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _goToLogin, // ← DÉJÀ CORRECT
                child: const Text('Passer'),
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return _buildSlide(slide);
                },
              ),
            ),

            // Progress dots
            _buildDots(),

            // CTA Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: _currentPage == _slides.length - 1
                    ? _goToLogin // ← CORRIGER ICI AUSSI
                    : _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius)),
                ),
                child: Text(_currentPage == _slides.length - 1 ? 'Commencer' : 'Suivant'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(Map<String, String> slide) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(slide['emoji']!, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 40),
          Text(
            slide['title']!,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide['description']!,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (index) {
        return Container(
          width: _currentPage == index ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _currentPage == index ? const Color(0xFF27AE60) : Colors.grey,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  void _nextPage() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
  }

  void _goToLogin() {
    // CORRECTION : Utiliser GoRouter au lieu de Navigator
    context.go('/login'); // ← VOICI LA CORRECTION
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

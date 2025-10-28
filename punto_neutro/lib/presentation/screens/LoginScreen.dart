import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:punto_neutro/presentation/screens/news_feed_screen.dart';
import 'package:punto_neutro/presentation/viewmodels/auth_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignInSelected = true;
  bool _obscurePassword = true;

  // Prefill con las credenciales quemadas en FakeAuthRepository
  final TextEditingController _emailController = TextEditingController(text: 'test@demo.com');
  final TextEditingController _passwordController = TextEditingController(text: 'password123');

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final borderRadius = BorderRadius.circular(20);

    // Si ya está logueado, navegar al Home
    if (vm.loggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => NewsFeedScreen()),
          );
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: borderRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título y subtítulo principal
                  Center(
                    child: Column(
                      children: const [
                        Icon(Icons.description_outlined, size: 40, color: Colors.black87),
                        SizedBox(height: 8),
                        Text('Punto Neutro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Fighting misinformation',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'A collaborative platform where the community verifies news in real-time to combat disinformation.',
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Imagen
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/image1.jpeg',
                      height: 150, width: double.infinity, fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lista con puntos
                  Column(
                    children: const [
                      _BulletPoint(text: 'Source credibility analysis'),
                      _BulletPoint(text: 'Real-time collaborative verification'),
                      _BulletPoint(text: 'Network of verified users'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Panel acceso
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.grey[100]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Access your account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 4),
                        const Text('Enter your credentials to continue', style: TextStyle(color: Colors.black54)),
                        const SizedBox(height: 12),

                        // Selector Sign In / Register
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), color: Colors.grey[300]),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isSignInSelected = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      color: _isSignInSelected ? Colors.white : Colors.transparent,
                                    ),
                                    child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isSignInSelected = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      color: _isSignInSelected ? Colors.transparent : Colors.white,
                                    ),
                                    child: const Text('Register', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Email
                        const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'you@example.com',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide.none),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Password
                        const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide.none),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.black38),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Botón Sign In
                        SizedBox(
                          width: double.infinity, height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: vm.loading
                                ? null
                                : () {
                                    if (_isSignInSelected) {
                                      vm.loginWithPassword(
                                        _emailController.text.trim(),
                                        _passwordController.text.trim(),
                                      );
                                    } else {
                                      vm.registerWithPassword(
                                        _emailController.text.trim(),
                                        _passwordController.text.trim(),
                                      );
                                    }
                                  },
                            child: vm.loading
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(_isSignInSelected ? 'Sign In' : 'Register', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Botón Fingerprint (opcional para probar huella)
                        SizedBox(
                          width: double.infinity, height: 44,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Sign in with fingerprint'),
                            onPressed: vm.loading ? null : vm.loginWithBiometric,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Forgot password (placeholder)
                        Center(
                          child: GestureDetector(
                            onTap: () {},
                            child: const Text(
                              'Forgot your password?',
                              style: TextStyle(fontSize: 12, color: Colors.black54, decoration: TextDecoration.underline),
                            ),
                          ),
                        ),

                        if (vm.error != null) ...[
                          const SizedBox(height: 12),
                          Text(vm.error!, style: const TextStyle(color: Colors.red)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20), // espacio final
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 10, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }
}

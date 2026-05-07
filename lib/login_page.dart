import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _auth = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool isLogin = true; // Toggle între Login și Register
  bool _isLoading = false; // Flag pentru starea de încărcare

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Validare de bază
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Te rugăm să completezi toate câmpurile.")),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Parola trebuie să aibă minimum 6 caractere.")),
      );
      return;
    }

    // 1. Pornim starea de încărcare
    setState(() => _isLoading = true);

    dynamic user;
    try {
      if (isLogin) {
        user = await _auth.loginWithEmail(email, password);
      } else {
        user = await _auth.registerWithEmail(email, password);
      }

      // 2. Dacă logarea a eșuat, oprim încărcarea și afișăm eroarea
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Eroare: Verifică datele sau conexiunea.")),
          );
        }
      } 

      
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Eroare neprevăzută: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView( // Previne erorile când apare tastatura
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.recycling, size: 80, color: Colors.green.shade700),
              const SizedBox(height: 20),
              Text(
                isLogin ? "Bine ai revenit!" : "Creează un cont", 
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
              ),
              const SizedBox(height: 10),
              Text(
                isLogin ? "Autentifică-te pentru a continua" : "Alătură-te comunității noastre eco",
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),
              
              // Email Field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              
              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Parolă",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 30),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        isLogin ? "AUTENTIFICARE" : "ÎNREGISTRARE",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Switch between Login/Register
              TextButton(
                onPressed: () => setState(() {
                  isLogin = !isLogin;
                  _isLoading = false;
                }),
                child: Text(
                  isLogin ? "Nu ai cont? Înregistrează-te" : "Ai deja cont? Loghează-te",
                  style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../main.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';
  bool _isSearching = false;


  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      await ApiService.login(_emailController.text.trim(), _passwordController.text);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _autoDiscover() async {
    setState(() { _isSearching = true; _errorMessage = 'Searching for server on local network...'; });
    final found = await ApiService.findServerOnLocalNetwork();
    if (mounted) {
      setState(() {
        _isSearching = false;
        if (found != null) {
          _errorMessage = 'Found server: $found';
          // Try to login if the fields are not empty
          if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
             _login();
          }
        } else {
          _errorMessage = 'Server not found automatically. Check settings.';
        }
      });
    }
  }

  void _showServerSettings() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1e1e1e),
        title: const Text('Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter backend URL (including http:// and port):', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: ApiService.getServerHostSync(),
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF2a2a2a),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiService.setServerHost('');
              if (mounted) Navigator.pop(context);
              setState(() => _errorMessage = 'Reverted to default IP');
            },
            child: const Text('Reset', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await ApiService.setServerHost(controller.text.trim());
              }
              if (mounted) Navigator.pop(context);
              setState(() => _errorMessage = 'Server host updated');
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFFE1306C), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.grey, size: 20),
            onPressed: _showServerSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              const Text('GMinsta',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Share your world',
                  style: TextStyle(color: Colors.grey, fontSize: 15)),
              const SizedBox(height: 24),

              // Auto-Discover Button (Always Visible)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSearching ? null : _autoDiscover,
                  icon: _isSearching 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                    : const Icon(Icons.wifi_find, size: 20),
                  label: Text(_isSearching ? 'Scanning Local Network...' : 'Auto-Discover Local Server'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2a2a2a),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Error
              if (_errorMessage.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.4))),
                  child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),



              // Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF262626),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE1306C))),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.grey),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF262626),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE1306C))),
                ),
              ),
              const SizedBox(height: 28),

              // Sign In Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE1306C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Sign In',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),

              // Sign Up redirect
              TextButton(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text.rich(TextSpan(children: [
                  TextSpan(text: "Don't have an account? ", style: TextStyle(color: Colors.grey)),
                  TextSpan(text: 'Sign up', style: TextStyle(color: Color(0xFFE1306C), fontWeight: FontWeight.bold)),
                ])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

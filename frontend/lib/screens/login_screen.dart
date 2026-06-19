import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/notification_action_dispatcher.dart';
import '../services/reminder_action_service.dart';
import '../main.dart' show navigatorKey;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _emailSignIn = TextEditingController();
  final _passSignIn = TextEditingController();
  final _emailRegister = TextEditingController();
  final _passRegister = TextEditingController();
  final _confirmPass = TextEditingController();
  final _signInFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ensureAuthReady();
  }

  Future<void> _ensureAuthReady() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.initialized) {
      await auth.init();
    }
    if (!mounted) return;
    if (auth.isLoggedIn) {
      final prov = Provider.of<ReminderProvider>(context, listen: false);
      await prov.loadAll();
      await processPendingNotificationAction(
        actionService: ReminderActionService(),
        onUiRefresh: () => prov.refreshFromRepository(),
        onOpenDetails: (id) {
          navigatorKey.currentState?.pushNamed('/details', arguments: id);
        },
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  Future<void> _afterAuthSuccess() async {
    final prov = Provider.of<ReminderProvider>(context, listen: false);
    await prov.loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailSignIn.dispose();
    _passSignIn.dispose();
    _emailRegister.dispose();
    _passRegister.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.indigo.shade600),
      suffixIcon: label.toLowerCase().contains('password')
          ? IconButton(
              icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off, color: Colors.indigo.shade400),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            )
          : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.indigo.shade600, width: 2)),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo.shade50, Colors.blue.shade50, Colors.purple.shade50],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo & Title
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo.shade600, Colors.purple.shade400],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_active_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Reminder Pro',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                  ),
                  Text(
                    'Never forget important moments',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),
                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(colors: [Colors.indigo.shade600, Colors.purple.shade400]),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey.shade600,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      padding: const EdgeInsets.all(4),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Sign In'),
                        Tab(text: 'Register'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Tab Content
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Sign In Tab
                        _buildSignInForm(context, auth),
                        // Register Tab
                        _buildRegisterForm(context, auth),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Footer
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      'Manage reminders with voice guidance, notifications, and cloud sync.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
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

  Widget _buildSignInForm(BuildContext context, AuthProvider auth) {
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailSignIn,
            decoration: _buildInputDecoration('Email Address', Icons.email_rounded),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passSignIn,
            decoration: _buildInputDecoration('Password', Icons.lock_rounded),
            obscureText: !_showPassword,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Password is required';
              if (value.trim().length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _loading
                ? null
                : () async {
                    if (!_signInFormKey.currentState!.validate()) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    setState(() => _loading = true);
                    String? errorMessage;
                    try {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      if (!auth.initialized) await auth.init();
                      await auth.signIn(_emailSignIn.text.trim(), _passSignIn.text.trim());
                      await _afterAuthSuccess();
                    } catch (e) {
                      errorMessage = e.toString().replaceFirst('Exception: ', '');
                    }
                    if (!mounted) return;
                    setState(() => _loading = false);
                    if (errorMessage != null) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red.shade600),
                      );
                      return;
                    }
                    await processPendingNotificationAction(
                      actionService: ReminderActionService(),
                      onUiRefresh: () async {
                        final p = Provider.of<ReminderProvider>(context, listen: false);
                        await p.refreshFromRepository();
                      },
                      onOpenDetails: (id) {
                        navigatorKey.currentState?.pushNamed('/details', arguments: id);
                      },
                    );
                    if (!mounted) return;
                    navigator.pushReplacementNamed('/dashboard');
                  },
            icon: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded),
            label: Text(_loading ? 'Signing in...' : 'Sign In', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.indigo.shade600,
              foregroundColor: Colors.white,
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(BuildContext context, AuthProvider auth) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailRegister,
            decoration: _buildInputDecoration('Email Address', Icons.email_rounded),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passRegister,
            decoration: _buildInputDecoration('Password', Icons.lock_rounded),
            obscureText: !_showPassword,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Password is required';
              if (value.trim().length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPass,
            decoration: _buildInputDecoration('Confirm Password', Icons.lock_rounded),
            obscureText: !_showPassword,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Confirm your password';
              if (value.trim() != _passRegister.text.trim()) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loading
                ? null
                : () async {
                    if (!_registerFormKey.currentState!.validate()) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    setState(() => _loading = true);
                    String? errorMessage;
                    try {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      if (!auth.initialized) await auth.init();
                      await auth.register(_emailRegister.text.trim(), _passRegister.text.trim());
                      await _afterAuthSuccess();
                    } catch (e) {
                      errorMessage = e.toString().replaceFirst('Exception: ', '');
                    }
                    if (!mounted) return;
                    setState(() => _loading = false);
                    if (errorMessage != null) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red.shade600),
                      );
                      return;
                    }
                    await processPendingNotificationAction(
                      actionService: ReminderActionService(),
                      onUiRefresh: () async {
                        final p = Provider.of<ReminderProvider>(context, listen: false);
                        await p.refreshFromRepository();
                      },
                      onOpenDetails: (id) {
                        navigatorKey.currentState?.pushNamed('/details', arguments: id);
                      },
                    );
                    if (!mounted) return;
                    navigator.pushReplacementNamed('/dashboard');
                  },
            icon: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.app_registration_rounded),
            label: Text(_loading ? 'Creating account...' : 'Create Account', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }
}

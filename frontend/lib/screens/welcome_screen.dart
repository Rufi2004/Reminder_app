import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/notification_action_dispatcher.dart';
import '../services/reminder_action_service.dart';
import '../main.dart' show navigatorKey;

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    await auth.init();

    if (!mounted) return;

    if (auth.isLoggedIn) {
      final prov = Provider.of<ReminderProvider>(context, listen: false);
      await prov.loadAll();

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/dashboard');

      await processPendingNotificationAction(
        actionService: ReminderActionService(),
        onUiRefresh: () => prov.refreshFromRepository(),
        onOpenDetails: (id) {
          navigatorKey.currentState?.pushNamed('/details', arguments: id);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5C6BC0), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: !auth.initialized
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.alarm, size: 120, color: Colors.white70),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome to Reminder App',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Stay on top of everything',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 48),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.indigo,
                          elevation: 6,
                        ),
                        onPressed: () =>
                            Navigator.of(context).pushReplacementNamed('/'),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

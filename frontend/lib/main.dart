import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/reminder_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/reminder_details_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/history_screen.dart';
import 'services/notification_action_dispatcher.dart';
import 'services/notification_background_handler.dart';
import 'services/notification_service.dart';
import 'services/reminder_action_service.dart';
import 'controllers/reminder_controller.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _handleNotificationPayload(String payload) async {
  if (payload.isEmpty) return;
  final handled = await ReminderActionService().executePayload(payload);
  if (!handled) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPendingNotificationActionKey, payload);
    return;
  }

  final ctx = navigatorKey.currentContext;
  if (ctx != null) {
    await Provider.of<ReminderProvider>(ctx, listen: false)
        .refreshFromRepository();
    final parsed = ReminderActionService.parsePayload(payload);
    if (parsed?.action == 'OPEN_ACTION') {
      navigatorKey.currentState?.pushNamed('/details', arguments: parsed!.id);
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notif = NotificationService();

  await notif.init(
    onForeground: (payload) async {
      if (payload == null || payload.isEmpty) return;
      debugPrint('[NOTIF] Foreground tap: $payload');
      await _handleNotificationPayload(payload);
    },
  );

  final launchPayload = await notif.consumeLaunchPayload();
  if (launchPayload != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPendingNotificationActionKey, launchPayload);
    debugPrint('[NOTIF] Saved cold-start launch payload: $launchPayload');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[NOTIF] App resumed — checking pending actions');
      processPendingNotificationAction(
        actionService: ReminderActionService(),
        onUiRefresh: () async {
          final ctx = navigatorKey.currentContext;
          if (ctx == null) return;
          await Provider.of<ReminderProvider>(ctx, listen: false)
              .refreshFromRepository();
        },
        onOpenDetails: (id) {
          navigatorKey.currentState?.pushNamed('/details', arguments: id);
        },
      );

      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        final provider = Provider.of<ReminderProvider>(ctx, listen: false);
        ReminderController().checkMissedReminders(provider.reminders);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = ReminderProvider();
            ReminderActionService().onReminderChanged =
                provider.applyReminderUpdate;
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Reminder App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          scaffoldBackgroundColor: Colors.grey.shade50,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                vertical: 18, horizontal: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.indigo.shade300)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
        initialRoute: '/welcome',
        routes: {
          '/welcome':   (ctx) => const WelcomeScreen(),
          '/':          (ctx) => const LoginScreen(),
          '/dashboard': (ctx) => const DashboardScreen(),
          '/reminders': (ctx) => const RemindersScreen(),
          '/details':   (ctx) => const ReminderDetailsScreen(),
          '/history':   (ctx) => const HistoryScreen(),
        },
      ),
    );
  }
}

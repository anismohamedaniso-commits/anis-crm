import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:anis_crm/state/app_state.dart';
import 'package:anis_crm/services/lead_service.dart';
import 'package:anis_crm/services/activity_service.dart';
import 'package:anis_crm/services/kpi_service.dart';
import 'package:anis_crm/services/campaign_service.dart';
import 'package:anis_crm/supabase/supabase_config.dart';
import 'package:anis_crm/services/channel_service.dart';
import 'package:anis_crm/services/ai_executor.dart';
import 'package:anis_crm/services/auth_service.dart';
import 'package:anis_crm/services/notification_service.dart';
import 'theme.dart';
import 'nav.dart';

/// Main entry point for the application
///
/// This sets up:
/// - Supabase initialization
/// - go_router navigation
/// - Material 3 theming with light/dark modes
Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Capture framework errors to the console for easier debugging
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('FlutterError: \\n${details.exceptionAsString()}');
      if (details.stack != null) debugPrint(details.stack.toString());
    };

    // Catch uncaught async errors outside the Flutter framework
    // Ensures we see exceptions from timers, isolates, and platform channels
    // in the Dreamflow Debug Console
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('PlatformDispatcher error: $error');
      debugPrint(stack.toString());
      return true; // handled
    };

    // Render a friendly in-app error widget so crashes are visible in Preview
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: Colors.red.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Something went wrong', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red)),
              const SizedBox(height: 6),
              Text(details.exceptionAsString(), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    };

    debugPrint('App start: initializing Supabase...');
    await SupabaseConfig.initialize();
    debugPrint('Supabase initialized');

    // Load local data stores
    debugPrint('Loading LeadService...');
    await LeadService.instance.load();
    debugPrint('LeadService loaded');

    debugPrint('Loading ActivityService...');
    await ActivityService.instance.load();
    debugPrint('ActivityService loaded');

    debugPrint('Loading KpiService...');
    await KpiService.instance.load();
    debugPrint('KpiService loaded');

    debugPrint('Loading CampaignService...');
    await CampaignService.instance.load();
    debugPrint('CampaignService loaded');

    final appState = AppState();
    debugPrint('Loading AppState...');
    await appState.init();
    debugPrint('AppState loaded');

    // Try to hydrate channel toggles from Supabase (no-op if not authenticated)
    debugPrint('Hydrating channels (if authenticated)...');
    await ChannelService.instance.hydrateFromRemote(appState);
    debugPrint('Channel hydration complete');

    // Initialize centralized AI executor (connectivity + auto-triggers)
    debugPrint('Initializing AI Executor...');
    await AiExecutor.instance.init(appState);
    debugPrint('AI Executor initialized');

    // Initialize auth and listen to Supabase auth state
    debugPrint('Initializing Auth...');
    AuthService.instance.init();
    await AuthService.instance.tryAutoLogin();
    debugPrint('Auth check complete: logged in = ${AuthService.instance.isLoggedIn}');

    // Start notification polling if logged in
    if (AuthService.instance.isLoggedIn) {
      NotificationService.instance.startPolling();
    }

    // Listen to auth changes to refresh router and reload data
    AuthService.instance.addListener(() {
      AppRouter.router.refresh();
      if (AuthService.instance.isLoggedIn) {
        // Reset services to force fresh data for new user session
        LeadService.instance.reset();
        KpiService.instance.reset();
        LeadService.instance.load();
        KpiService.instance.load();
        CampaignService.instance.load();
        NotificationService.instance.startPolling();
      } else {
        LeadService.instance.reset();
        KpiService.instance.reset();
        NotificationService.instance.stopPolling();
      }
    });

    runApp(MyApp(appState: appState));
  }, (Object error, StackTrace stack) {
    debugPrint('Uncaught zone error: $error');
    debugPrint(stack.toString());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    // As you extend the app, use MultiProvider to wrap the app
    // and provide state to all widgets
    // Example:
    // return MultiProvider(
    //   providers: [
    //     ChangeNotifierProvider(create: (_) => ExampleProvider()),
    //   ],
    //   child: MaterialApp.router(
    //     title: 'Dreamflow Starter',
    //     debugShowCheckedModeBanner: false,
    //     routerConfig: AppRouter.router,
    //   ),
    // );
    return ChangeNotifierProvider(
      create: (_) => appState,
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp.router(
          title: 'Tick&Talk CRM',
          debugShowCheckedModeBanner: false,

          // Theme configuration
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,

          // Router configuration
          routerConfig: AppRouter.router,
        ),
      ),
    );
  }
}

import 'package:go_router/go_router.dart';
import 'package:anis_crm/layout/app_shell.dart';
import 'package:anis_crm/pages/dashboard_page.dart';
import 'package:anis_crm/pages/lead_detail_page.dart';
import 'package:anis_crm/pages/settings_page.dart';
import 'package:anis_crm/pages/leads_page.dart';
import 'package:anis_crm/pages/pipeline_page.dart';
import 'package:anis_crm/pages/calendar_page.dart';
import 'package:anis_crm/pages/email_marketing_page.dart';
import 'package:anis_crm/pages/integrations_page.dart';
import 'package:anis_crm/pages/kpi_dashboard_page.dart';
// ai_chat_page removed
import 'package:anis_crm/pages/login_page.dart';
import 'package:anis_crm/pages/signup_page.dart';
import 'package:anis_crm/pages/team_page.dart';
import 'package:anis_crm/pages/profile_page.dart';
import 'package:anis_crm/pages/activity_feed_page.dart';
import 'package:anis_crm/pages/tasks_page.dart';
import 'package:anis_crm/pages/team_chat_page.dart';
import 'package:anis_crm/pages/leaderboard_page.dart';
// deals page removed
import 'package:anis_crm/pages/reports_page.dart';
import 'package:anis_crm/pages/automation_page.dart';
import 'package:anis_crm/pages/custom_fields_page.dart';
import 'package:anis_crm/pages/masterclass_page.dart';
import 'package:anis_crm/services/auth_service.dart';
import 'package:anis_crm/utils/page_transitions.dart';

/// GoRouter configuration for app navigation
///
/// This uses go_router for declarative routing, which provides:
/// - Type-safe navigation
/// - Deep linking support (web URLs, app links)
/// - Easy route parameters
/// - Navigation guards and redirects
///
/// To add a new route:
/// 1. Add a route constant to AppRoutes below
/// 2. Add a GoRoute to the routes list
/// 3. Navigate using context.go() or context.push()
/// 4. Use context.pop() to go back.
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      final loggedIn = AuthService.instance.isLoggedIn;
      final path = state.uri.toString();
      final isAuthPage = path == AppRoutes.login || path == AppRoutes.signUp;
      if (!loggedIn && !isAuthPage) return AppRoutes.login;
      if (loggedIn && isAuthPage) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => FadeTransitionPage(child: const LoginPage()),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        name: 'signUp',
        pageBuilder: (context, state) => FadeTransitionPage(child: const SignUpPage()),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) => FadeTransitionPage(child: const DashboardPage()),
          ),
          // Lead detail (UI only). Example: /app/lead/123
          GoRoute(
            path: AppRoutes.leadDetail,
            name: 'leadDetail',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'];
              return SlideUpTransitionPage(child: LeadDetailPage(leadId: id));
            },
          ),
          GoRoute(
            path: AppRoutes.leads,
            name: 'leads',
            pageBuilder: (context, state) => FadeTransitionPage(child: const LeadsPage()),
          ),
          GoRoute(
            path: AppRoutes.pipeline,
            name: 'pipeline',
            pageBuilder: (context, state) => FadeTransitionPage(child: const PipelinePage()),
          ),
          GoRoute(
            path: AppRoutes.calendar,
            name: 'calendar',
            pageBuilder: (context, state) => FadeTransitionPage(child: const CalendarPage()),
          ),
          GoRoute(
            path: AppRoutes.emailMarketing,
            name: 'emailMarketing',
            pageBuilder: (context, state) => FadeTransitionPage(child: const EmailMarketingPage()),
          ),
          GoRoute(
            path: AppRoutes.kpis,
            name: 'kpis',
            pageBuilder: (context, state) => FadeTransitionPage(child: const KpiDashboardPage()),
          ),
          GoRoute(
            path: AppRoutes.integrations,
            name: 'integrations',
            pageBuilder: (context, state) => FadeTransitionPage(child: const IntegrationsPage()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            pageBuilder: (context, state) => FadeTransitionPage(child: const SettingsPage()),
          ),
          GoRoute(
            path: AppRoutes.team,
            name: 'team',
            pageBuilder: (context, state) => FadeTransitionPage(child: const TeamPage()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            pageBuilder: (context, state) => SlideUpTransitionPage(child: const ProfilePage()),
          ),
          GoRoute(
            path: AppRoutes.activityFeed,
            name: 'activityFeed',
            pageBuilder: (context, state) => FadeTransitionPage(child: const ActivityFeedPage()),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            name: 'tasks',
            pageBuilder: (context, state) => FadeTransitionPage(child: const TasksPage()),
          ),
          GoRoute(
            path: AppRoutes.chat,
            name: 'chat',
            pageBuilder: (context, state) => FadeTransitionPage(child: const TeamChatPage()),
          ),
          GoRoute(
            path: AppRoutes.leaderboard,
            name: 'leaderboard',
            pageBuilder: (context, state) => FadeTransitionPage(child: const LeaderboardPage()),
          ),
          GoRoute(
            path: AppRoutes.reports,
            name: 'reports',
            pageBuilder: (context, state) => FadeTransitionPage(child: const ReportsPage()),
          ),
          GoRoute(
            path: AppRoutes.automation,
            name: 'automation',
            pageBuilder: (context, state) => FadeTransitionPage(child: const AutomationPage()),
          ),
          GoRoute(
            path: AppRoutes.customFields,
            name: 'customFields',
            pageBuilder: (context, state) => FadeTransitionPage(child: const CustomFieldsPage()),
          ),
          GoRoute(
            path: AppRoutes.masterclass,
            name: 'masterclass',
            pageBuilder: (context, state) => FadeTransitionPage(child: const MasterclassPage()),
          ),
        ],
      ),
    ],
  );
}

/// Route path constants
/// Use these instead of hard-coding route strings
class AppRoutes {
  static const String login = '/login';
  static const String signUp = '/signup';
  static const String dashboard = '/app/dashboard';
  static const String leadDetail = '/app/lead/:id';
  static const String leads = '/app/leads';
  static const String pipeline = '/app/pipeline';
  static const String calendar = '/app/calendar';
  static const String emailMarketing = '/app/email-marketing';
  static const String kpis = '/app/kpis';
  static const String integrations = '/app/integrations';
  // aiChat removed
  static const String settings = '/app/settings';
  static const String team = '/app/team';
  static const String profile = '/app/profile';
  static const String activityFeed = '/app/activity';
  static const String tasks = '/app/tasks';
  static const String chat = '/app/chat';
  static const String leaderboard = '/app/leaderboard';
  // deals page removed
  static const String reports = '/app/reports';
  static const String automation = '/app/automation';
  static const String customFields = '/app/custom-fields';
  static const String masterclass = '/app/masterclass';
}

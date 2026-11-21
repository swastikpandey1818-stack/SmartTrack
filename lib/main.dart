import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_controller.dart';
import 'core/theme.dart';
import 'ui/screens/alerts_screen.dart';
import 'ui/screens/analytics_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: AppColors.bg,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SmartTrackApp());
}

class SmartTrackApp extends StatefulWidget {
  const SmartTrackApp({super.key});
  @override
  State<SmartTrackApp> createState() => _SmartTrackAppState();
}

class _SmartTrackAppState extends State<SmartTrackApp> {
  final AppController _controller = AppController();
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    _controller.init();
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Track',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ControllerScope(
        controller: _controller,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: (_splashDone && _controller.ready)
                ? const _Shell(key: ValueKey('shell'))
                : const _Splash(key: ValueKey('splash')),
          ),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: GradientBackground(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Image.asset('assets/icon/icon.png', width: 190, height: 190),
                ),
              ),
              const SizedBox(height: 22),
              const Text('Monitor · Automate · Grow',
                  style: TextStyle(color: AppColors.textDim, letterSpacing: 1.2)),
              const SizedBox(height: 26),
              const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.lime)),
            ]),
          ),
        ),
      );
}

class _Shell extends StatefulWidget {
  const _Shell({super.key});
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final c = ControllerScope.of(context);
    final pages = <Widget>[
      HomeScreen(onOpenAlerts: () => _go(2), onOpenSettings: () => _go(3)),
      const AnalyticsScreen(),
      const AlertsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: GradientBackground(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.96),
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(26),
            ),
            child: NavigationBar(
              height: 64,
              backgroundColor: Colors.transparent,
              indicatorColor: AppColors.emerald.withValues(alpha: 0.25),
              selectedIndex: _index,
              onDestinationSelected: _go,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded, color: AppColors.lime),
                    label: 'Home'),
                const NavigationDestination(
                    icon: Icon(Icons.bar_chart_rounded),
                    selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.lime),
                    label: 'Analytics'),
                NavigationDestination(
                    icon: Badge(
                        isLabelVisible: c.alerts.isNotEmpty,
                        label: Text('${c.alerts.length}'),
                        child: const Icon(Icons.notifications_none_rounded)),
                    selectedIcon: const Icon(Icons.notifications_rounded, color: AppColors.lime),
                    label: 'Alerts'),
                const NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded, color: AppColors.lime),
                    label: 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

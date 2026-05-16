import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/network_provider.dart';
import 'services/serial_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/auditor_screen.dart';
import 'screens/spectrum_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => NetworkProvider()..init(),
      child: const SafeNetApp(),
    ),
  );
}

class SafeNetApp extends StatelessWidget {
  const SafeNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAFE-NET AUDITOR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          background: Color(0xFF000000),
          surface: Color(0xFF0A0A0A),
          primary: Color(0xFFFFFFFF),
          secondary: Color(0xFF39FF14),
          error: Color(0xFFFF0000),
        ),
        textTheme: GoogleFonts.spaceMonoTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        useMaterial3: false,
      ),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    AuditorScreen(),
    SpectrumScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.grid_view_rounded, label: 'DASHBOARD'),
    _NavItem(icon: Icons.security,           label: 'AUDITOR'),
    _NavItem(icon: Icons.bar_chart,          label: 'SPECTRUM'),
    _NavItem(icon: Icons.history,            label: 'HISTORY'),
    _NavItem(icon: Icons.settings,           label: 'SETTINGS'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const _AppHeader(),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: _RetroNavBar(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String   label;
  const _NavItem({required this.icon, required this.label});
}

class _AppHeader extends StatefulWidget {
  const _AppHeader();
  @override
  State<_AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<_AppHeader> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _cursorVisible = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed || s == AnimationStatus.dismissed) {
          setState(() => _cursorVisible = !_cursorVisible);
          _ctrl.reset();
          _ctrl.forward();
        }
      });
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (ctx, net, _) {
        String statusLine;
        if (net.isConnected) {
          statusLine = 'STATUS:\nSNIFFING';
        } else if (net.serialState == SerialState.connecting) {
          statusLine = 'STATUS:\nCONNECTING';
        } else if (net.serialState == SerialState.error) {
          statusLine = 'STATUS:\nERROR';
        } else {
          statusLine = 'STATUS:\nDISCONNECTED';
        }

        return Container(
          color: Colors.black,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_tethering, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '[ SAFE-NET AUDITOR | IT3R2]',
                          style: GoogleFonts.spaceMono(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.bold, letterSpacing: 1,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(statusLine,
                            style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 9, height: 1.3),
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(width: 4),
                          Text(_cursorVisible ? '█' : ' ',
                            style: GoogleFonts.spaceMono(color: const Color(0xFF39FF14), fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(height: 2, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RetroNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;
  const _RetroNavBar({required this.currentIndex, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.black,
                      border: Border.all(color: active ? Colors.white : Colors.white54, width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(items[i].icon, size: 16, color: active ? Colors.black : Colors.white),
                        const SizedBox(height: 2),
                        Text(items[i].label,
                          style: GoogleFonts.spaceMono(
                            fontSize: 6.5,
                            color: active ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          )),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

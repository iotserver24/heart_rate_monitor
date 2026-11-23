import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/live_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/health_info_screen.dart';
import 'screens/connect_screen.dart';
import 'services/ble_service.dart';
import 'services/wifi_service.dart';

void main() {
  runApp(const HeartRateApp());
}

class HeartRateApp extends StatelessWidget {
  const HeartRateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
        ChangeNotifierProvider(create: (_) => WifiService()),
      ],
      child: MaterialApp(
        title: 'Heart Rate Monitor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0A0E21),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Color(0xFF0A0E21),
              statusBarIconBrightness: Brightness.light,
            ),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: IconThemeData(color: Colors.white),
          ),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFE53935),
            secondary: Color(0xFF29B6F6),
            surface: Color(0xFF1A1F3A),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF1A1F3A),
            selectedItemColor: Color(0xFFE53935),
            unselectedItemColor: Colors.white38,
            type: BottomNavigationBarType.fixed,
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const MainNav(),
          '/connect': (context) => const ConnectScreen(),
        },
      ),
    );
  }
}

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _currentIndex = 0;

  final _screens = [
    const LiveScreen(),
    const StatsScreen(),
    const HealthInfoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart),
            label: 'Live',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety),
            label: 'Health',
          ),
        ],
      ),
    );
  }
}

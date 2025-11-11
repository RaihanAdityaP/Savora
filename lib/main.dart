import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/profile_screen.dart';
import 'utils/supabase_client.dart';
import 'services/notification_service.dart';

// Global navigator key untuk navigation dari notification
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://risxgbbsxuerozzsaxzb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpc3hnYmJzeHVlcm96enNheHpiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5ODc2MjAsImV4cCI6MjA3NTU2MzYyMH0.Gr2-m11pdelRgjy4YKuMzj2VDc_92hH3U0vtw2MNwbw',
  );
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Check banned status
  await _checkBannedStatus();
  
  runApp(const MyApp());
}

Future<void> _checkBannedStatus() async {
  try {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      final profile = await supabase
          .from('profiles')
          .select('is_banned')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      
      if (profile != null && profile['is_banned'] == true) {
        await supabase.auth.signOut();
      }
    }
  } catch (e) {
    debugPrint('Error checking banned status: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // Setup notification listener jika user sudah login
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      NotificationService().setupRealtimeListener(userId);
    }
  }

  @override
  void dispose() {
    NotificationService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, 
      title: 'Savora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      home: supabase.auth.currentUser == null 
          ? const LoginScreen() 
          : const HomeScreen(),
      // Define routes untuk navigation dari notifikasi
      onGenerateRoute: (settings) {
        // Handle route dari notification
        if (settings.name == '/recipe') {
          final recipeId = settings.arguments as String?;
          if (recipeId != null) {
            return MaterialPageRoute(
              builder: (context) => DetailScreen(recipeId: recipeId),
            );
          }
        } else if (settings.name == '/profile') {
          final userId = settings.arguments as String?;
          if (userId != null) {
            return MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: userId),
            );
          }
        }
        
        // Default route
        return MaterialPageRoute(builder: (context) => const HomeScreen());
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'utils/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://risxgbbsxuerozzsaxzb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpc3hnYmJzeHVlcm96enNheHpiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5ODc2MjAsImV4cCI6MjA3NTU2MzYyMH0.Gr2-m11pdelRgjy4YKuMzj2VDc_92hH3U0vtw2MNwbw',
  );
  
  // ✅ Check banned status on app start
  await _checkBannedStatus();
  
  runApp(const MyApp());
}

// ✅ Function to check if current user is banned
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Savora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      home: supabase.auth.currentUser == null 
          ? const LoginScreen() 
          : const HomeScreen(),
    );
  }
}
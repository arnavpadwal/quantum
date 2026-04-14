import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/contact.dart';
import 'models/message.dart';
import 'models/profile.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/chats_home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/storage_service.dart';
import 'services/p2p_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  Hive.registerAdapter(ProfileAdapter());
  Hive.registerAdapter(ContactAdapter());
  Hive.registerAdapter(MessageAdapter());
  Hive.registerAdapter(MessageStatusAdapter());
  
  await StorageService.init();
  await P2PService.instance.init();
  await NotificationService().init();
  
  runApp(const QuantumApp());
}

class QuantumApp extends StatelessWidget {
  const QuantumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantum',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0b8ce9),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0b8ce9),
          brightness: Brightness.dark,
        ),
      ),
      home: FutureBuilder<bool>(
        future: StorageService.hasProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (!StorageService.hasSeenOnboarding()) {
            return const OnboardingScreen();
          }

          final hasProfile = snapshot.data ?? false;
          return hasProfile ? const ChatsHomeScreen() : const ProfileSetupScreen();
        },
      ),
    );
  }
}

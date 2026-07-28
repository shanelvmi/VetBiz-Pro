import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/facilities/select_facility_screen.dart';

import 'services/auth_service.dart';

import 'providers/product_provider.dart';
import 'providers/client_provider.dart';
import 'providers/service_provider.dart';
import 'providers/sale_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/facility_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/debt_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DebtProvider()),
        ChangeNotifierProvider(
          create: (context) => ServiceProvider(
            debtProvider: Provider.of<DebtProvider>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(create: (_) => SaleProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => ClientProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => FacilityProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: const VetBizProApp(),
    ),
  );
}

class VetBizProApp extends StatelessWidget {
  const VetBizProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VetBiz Pro',
      theme: ThemeData.light(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/selectFacility': (context) => const SelectFacilityScreen(),
      },
      home: const AppEntryPoint(),
    );
  }
}

class AppEntryPoint extends StatelessWidget {
  const AppEntryPoint({super.key});

  Future<Widget> _decideScreen(User user) async {
    try {
      final uid = user.uid;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) return const LoginScreen();

      final data = userDoc.data()!;
      final facilities = data['facilities'] as List<dynamic>?;

      if (facilities == null || facilities.isEmpty) {
        return const SelectFacilityScreen();
      }

      if (facilities.length == 1) {
        return const DashboardScreen();
      }

      return const SelectFacilityScreen();
    } catch (e) {
      debugPrint('Error deciding screen: $e');
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still connecting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User logged out or no user
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // User logged in → decide facility/dashboard
        return FutureBuilder<Widget>(
          future: _decideScreen(snapshot.data!),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError || !snap.hasData) {
              return const LoginScreen();
            }
            return snap.data!;
          },
        );
      },
    );
  }
}

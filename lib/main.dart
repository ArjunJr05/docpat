import 'package:docpat2/screens/auth/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'providers/auth_provider.dart';
import 'providers/document_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/share/share_view_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");
    
    // Initialize Firebase with error handling
    await Firebase.initializeApp();
    
    runApp(const HealthWalletApp());
  } catch (e) {
    print('Firebase initialization error: $e');
    // If initialization fails, show error screen
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('App Initialization Failed'),
              const SizedBox(height: 8),
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Restart app
                  main();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class HealthWalletApp extends StatelessWidget {
  const HealthWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
      ],
      child: MaterialApp(
        title: 'Health Record Wallet',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
        home: const AuthWrapper(), // Use home instead of initialRoute
        routes: {
          '/login': (context) => const AuthScreen(),
          '/home': (context) => const HomeScreen(),
          '/share': (context) => const ShareViewScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle dynamic routes like /share/:shareId
          final uri = Uri.parse(settings.name ?? '');
          if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'share') {
            final shareId = uri.pathSegments[1];
            return MaterialPageRoute(
              builder: (context) => ShareViewScreen(shareId: shareId),
            );
          }
          return null;
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        print('AuthWrapper - isLoading: ${authProvider.isLoading}');
        print('AuthWrapper - isAuthenticated: ${authProvider.isAuthenticated}');
        print('AuthWrapper - user: ${authProvider.user?.email}');
        
        // Show loading screen
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        // Show error screen if there's an authentication error
        if (authProvider.error != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Authentication Error',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      authProvider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        authProvider.clearError();
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Return the appropriate screen based on auth state
        return authProvider.isAuthenticated 
            ? const HomeScreen() 
            : const AuthScreen();
      },
    );
  }
}
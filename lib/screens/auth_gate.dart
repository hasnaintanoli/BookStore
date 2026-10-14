import '../theme/book_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'user_session.dart';

/// Restores a verified Firebase session, including server-granted admin access.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _decideStartRoute();
    });
  }

  Future<void> _decideStartRoute() async {
    String target = '/login';

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        final fresh = FirebaseAuth.instance.currentUser;
        if (fresh != null && fresh.emailVerified) {
          UserSession.setCurrentUser(
            await AuthService.instance.loadSession(fresh),
          );
          target = UserSession.isAdmin ? '/admin-dashboard' : '/main_shell';
        } else {
          await AuthService.instance.signOut();
          UserSession.logout();
        }
      }
    } catch (_) {
      // Leave the persisted Firebase session available for a login retry,
      // while ensuring no stale account data can be shown.
      UserSession.logout();
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, target);
  }

  @override
  Widget build(BuildContext context) {
    final green = context.bookColors.primary;
    final cream = context.bookColors.background;

    return Scaffold(
      backgroundColor: cream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, color: green, size: 56),
            const SizedBox(height: 20),
            CircularProgressIndicator(color: green),
          ],
        ),
      ),
    );
  }
}

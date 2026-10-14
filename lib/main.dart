import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/book.dart';
import 'screens/auth_gate.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/browser.dart';
import 'screens/liked.dart';
import 'screens/cart.dart';
import 'screens/profile.dart';
import 'screens/notifications.dart';
import 'screens/user_session.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/admin/manage_books_screen.dart';
import 'screens/admin/manage_users_screen.dart';
import 'screens/admin/manage_orders_screen.dart';
import 'services/user_data_service.dart';

import 'services/store_controller.dart';
import 'services/store_repository.dart';

import 'services/auth_service.dart';
import 'theme/book_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BookStoreApp());
}

class BookStoreApp extends StatefulWidget {
  const BookStoreApp({super.key, this.store, this.initialRoute = '/'});
  final StoreController? store;
  final String initialRoute;
  @override
  State<BookStoreApp> createState() => _BookStoreAppState();
}

class _BookStoreAppState extends State<BookStoreApp> {
  late final StoreController store;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<Map<String, dynamic>>? _accessSubscription;
  StreamSubscription<Order>? _orderAlerts;
  int _accessGeneration = 0;
  @override
  void initState() {
    super.initState();
    store = widget.store ?? StoreController(FirebaseStoreRepository());
    _orderAlerts = store.orderUpdates.listen((order) {
      if (!mounted ||
          order.userId != UserSession.uid ||
          !UserSession.pushNotifications)
        return;
      _messenger.currentState?.showSnackBar(
        SnackBar(
          content: Text('Order ${order.id}: ${order.status}'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () =>
                _navigator.currentState?.pushNamed('/notifications'),
          ),
        ),
      );
    });
    UserSession.changes.addListener(_sessionChanged);
    _sessionChanged();
  }

  void _sessionChanged() {
    final generation = ++_accessGeneration;
    _accessSubscription?.cancel();
    final uid = UserSession.uid;
    if (uid.isNotEmpty) {
      _accessSubscription = AuthService.instance
          .watchAccess(uid)
          .listen(
            (access) async {
              if (!mounted ||
                  generation != _accessGeneration ||
                  UserSession.uid != uid)
                return;
              if (access['disabled'] == true || access['removed'] == true) {
                // Clear local state even if an offline Firebase sign-out fails.
                UserSession.logout();
                _navigator.currentState?.pushNamedAndRemoveUntil(
                  '/login',
                  (_) => false,
                );
                _messenger.currentState?.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Your bookstore access has been blocked or removed.',
                    ),
                  ),
                );
                try {
                  await AuthService.instance.signOut();
                } catch (_) {}
                return;
              }
              final role = UserSession.bootstrapAdmin || access['admin'] == true
                  ? 'Admin'
                  : 'Customer';
              if (role != UserSession.role) {
                UserSession.role = role;
                UserSession.changes.value++;
                _navigator.currentState?.pushNamedAndRemoveUntil(
                  role == 'Admin' ? '/admin-dashboard' : '/main_shell',
                  (_) => false,
                );
              }
            },
            onError: (Object _) {
              // Store/profile streams show retry UI; permissions remain enforced by rules.
            },
          );
    } else {
      _accessSubscription = null;
    }
    store.bind(UserSession.uid, admin: UserSession.isAdmin);
    UserDataService.instance.bind(UserSession.uid);
  }

  @override
  void dispose() {
    _accessGeneration++;
    _accessSubscription?.cancel();
    UserSession.changes.removeListener(_sessionChanged);
    _orderAlerts?.cancel();
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  Future<void> _write(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      _messenger.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Changes could not be saved. Check your connection and try again.',
          ),
        ),
      );
      rethrow;
    }
  }

  Widget _live(Widget Function() page, {bool admin = false}) => AnimatedBuilder(
    animation: Listenable.merge([store, UserSession.profileChanges]),
    builder: (context, _) {
      if (!UserSession.isLoggedIn || (admin && !UserSession.isAdmin)) {
        return const LoginScreen();
      }
      if (store.loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (store.error != null) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(store.error!, textAlign: TextAlign.center),
                TextButton(
                  onPressed: _sessionChanged,
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () async {
                    await AuthService.instance.signOut();
                    UserSession.logout();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (_) => false,
                      );
                    }
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        );
      }
      return page();
    },
  );
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: UserSession.darkMode,
    builder: (context, dark, _) => MaterialApp(
      title: 'Book Store',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      navigatorKey: _navigator,
      theme: bookTheme(Brightness.light),
      darkTheme: bookTheme(Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: widget.initialRoute,
      onGenerateInitialRoutes: (route) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(name: route),
          builder: (_) =>
              route == '/login' ? const LoginScreen() : const AuthGate(),
        ),
      ],
      routes: {
        '/': (_) => const AuthGate(),
        '/login': (_) => const LoginScreen(),
        '/main_shell': (_) => _live(
          () => MainNavigationShell(
            key: ValueKey(UserSession.uid),
            dataUpdates: store,
            allBooks: store.books,
            cartItems: store.cart,
            orders: store.orders,
            savedBookIds: store.savedIds,
            onAddToCart: (book) => _write(() => store.addToCart(book)),
            onToggleSave: (id) => _write(() => store.toggleSaved(id)),
          ),
        ),
        '/cart': (_) => _live(
          () => CartScreen(
            cartItems: store.cart,
            currentQuote: (promoCode) => store.quote(promoCode: promoCode),
            updates: store,
            unavailableCartIds: store.unavailableCartIds,
            onRemoveUnavailable: () => _write(store.removeUnavailableItems),
            onPlaceOrder: store.placeOrder,
            onQuantityChanged: (book, quantity) =>
                _write(() => store.setQuantity(book, quantity)),
          ),
        ),
        '/admin-dashboard': (_) => _live(
          () => DashboardScreen(allBooks: store.books, orders: store.orders),
          admin: true,
        ),
        '/notifications': (_) => _live(
          () => NotificationsScreen(orders: store.orders, updates: store),
        ),
        '/manage-books': (_) => _live(
          () => ManageBooksScreen(
            allBooks: store.books,
            repository: store.repository,
          ),
          admin: true,
        ),
        '/manage-users': (_) =>
            _live(() => const ManageUsersScreen(), admin: true),
        '/manage-orders': (_) => _live(
          () => ManageOrdersScreen(
            orders: store.orders,
            repository: store.repository,
          ),
          admin: true,
        ),
        '/edit-profile': (_) => _live(
          () => ProfileScreen(
            orders: store.orders
                .where((o) => o.userId == UserSession.uid)
                .toList(),
            orderUpdates: store,
          ),
          admin: true,
        ),
      },
    ),
  );
}

class MainNavigationShell extends StatefulWidget {
  final Listenable dataUpdates;
  final List<Book> allBooks;
  final List<CartItem> cartItems;
  final List<Order> orders;
  final Set<String> savedBookIds;
  final Future<void> Function(Book) onAddToCart;
  final Future<void> Function(String) onToggleSave;

  const MainNavigationShell({
    super.key,
    required this.dataUpdates,
    required this.allBooks,
    required this.cartItems,
    required this.orders,
    required this.savedBookIds,
    required this.onAddToCart,
    required this.onToggleSave,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        allBooks: widget.allBooks,
        cartItems: widget.cartItems,
        savedBookIds: widget.savedBookIds,
        onAddToCart: widget.onAddToCart,
        onToggleSave: widget.onToggleSave,
      ),
      BrowserScreen(
        allBooks: widget.allBooks,
        cartItems: widget.cartItems,
        savedBookIds: widget.savedBookIds,
        onAddToCart: widget.onAddToCart,
        onToggleSave: widget.onToggleSave,
      ),
      LikedScreen(
        allBooks: widget.allBooks,
        cartItems: widget.cartItems,
        savedBookIds: widget.savedBookIds,
        onAddToCart: widget.onAddToCart,
        onToggleSave: widget.onToggleSave,
      ),
      ProfileScreen(orders: widget.orders, orderUpdates: widget.dataUpdates),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).unselectedWidgetColor,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view),
              label: 'Browse',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: widget.savedBookIds.isNotEmpty,
                label: Text('${widget.savedBookIds.length}'),
                child: const Icon(Icons.favorite_outline),
              ),
              activeIcon: Badge(
                isLabelVisible: widget.savedBookIds.isNotEmpty,
                label: Text('${widget.savedBookIds.length}'),
                child: const Icon(Icons.favorite),
              ),
              label: 'Saved',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

import '../../theme/book_theme.dart';
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../user_session.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';

class DashboardScreen extends StatefulWidget {
  final List<Book> allBooks;
  final List<Order> orders;

  const DashboardScreen({
    super.key,
    required this.allBooks,
    required this.orders,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  Future<void> _refreshUsers() async {
    final uid = UserSession.uid;
    try {
      final records = await AdminService.instance.listUsers();
      if (!mounted || UserSession.uid != uid) return;
      setState(() => UserSession.setUsersFromRecords(records));
    } catch (_) {
      if (mounted) _toast('User count could not be refreshed.');
    }
  }

  int get _books => widget.allBooks.length;
  int get _users => UserSession.users.length;
  int get _orders => widget.orders.length;
  double get _revenue => widget.orders.fold(0.0, (sum, o) => sum + o.total);

  List<Map<String, dynamic>> get _recent => widget.orders
      .take(3)
      .map(
        (o) => {
          'id': o.id,
          'name': o.shippingAddress,
          'items': o.items.length,
          'price': o.total.toStringAsFixed(2),
          'status': o.status,
        },
      )
      .toList();

  Future<void> _nav(String route) async {
    await Navigator.pushNamed(context, route);
    if (!mounted) return;
    setState(() {});
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _logout() async {
    var ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will be signed out of Margin Admin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AuthService.instance.signOut();
      UserSession.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (_) {
      if (mounted) _toast('Could not sign out. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bookColors.adminBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: context.bookColors.adminPrimary,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MARGIN ADMIN',
                        style: TextStyle(
                          color: context.bookColors.onPrimary.withValues(
                            alpha: 0.8,
                          ),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dashboard',
                        style: TextStyle(
                          color: context.bookColors.onPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.logout,
                      color: context.bookColors.onPrimary,
                    ),
                    onPressed: _logout,
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: context.bookColors.adminPrimary,
                onRefresh: () async {
                  await _refreshUsers();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _stat('$_books', 'Books in catalog', 'Live catalog'),
                          const SizedBox(width: 12),
                          _stat(
                            '$_users',
                            'Registered users',
                            'Firebase profiles',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _stat('$_orders', 'Orders', 'Live order history'),
                          const SizedBox(width: 12),
                          _stat(
                            '\$${(_revenue / 1000).toStringAsFixed(1)}k',
                            'Order value',
                            'Cash & card orders',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _action(
                            Icons.menu_book,
                            'Manage books',
                            () => _nav('/manage-books'),
                          ),
                          const SizedBox(width: 12),
                          _action(
                            Icons.people,
                            'Manage users',
                            () => _nav('/manage-users'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _action(
                            Icons.shopping_cart,
                            'Manage orders',
                            () => _nav('/manage-orders'),
                          ),
                          const SizedBox(width: 12),
                          _action(
                            Icons.bar_chart,
                            'My profile',
                            () => _nav('/edit-profile'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Recent orders',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.orders.isEmpty)
                        Center(
                          child: Text(
                            'No orders yet',
                            style: TextStyle(
                              color: context.bookColors.mutedText,
                            ),
                          ),
                        )
                      else
                        ..._recent.map(
                          (o) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _orderRow(o),
                          ),
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String v, String l, String s) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bookColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.bookColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            v,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: context.bookColors.adminPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l,
            style: TextStyle(
              fontSize: 12,
              color: context.bookColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _action(IconData i, String l, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: context.bookColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.bookColors.border),
        ),
        child: Row(
          children: [
            Icon(i, size: 18, color: context.bookColors.adminPrimary),
            const SizedBox(width: 8),
            Text(
              l,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _orderRow(Map<String, dynamic> o) {
    var s = o['status'] as String;
    var c = s == 'Shipped'
        ? Colors.blue
        : s == 'Delivered'
        ? Colors.green
        : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: context.bookColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.bookColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${o['id']} Â· ${o['name']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${o['items']} items Â· \$${o['price']}',
                style: TextStyle(
                  color: context.bookColors.secondaryText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Text(
            s,
            style: TextStyle(
              color: c,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

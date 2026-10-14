import '../../theme/book_theme.dart';
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/store_repository.dart';

class ManageOrdersScreen extends StatefulWidget {
  final List<Order> orders;
  final StoreRepository repository;

  const ManageOrdersScreen({
    super.key,
    required this.orders,
    required this.repository,
  });

  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen> {
  int _filterIdx = 0;
  final List<String> _filters = ['All', ...Order.statuses];

  // filter is index-based, all is 0 so keep a special case
  List<Order> get _vis {
    if (_filterIdx == 0) return widget.orders;
    var sel = _filters[_filterIdx];
    var out = <Order>[];
    var i = 0;
    while (i < widget.orders.length) {
      if (widget.orders[i].status == sel) out.add(widget.orders[i]);
      i++;
    }
    return out;
  }

  Color _statClr(String s) {
    switch (s) {
      case 'Shipped':
        return Colors.blue;
      case 'Delivered':
        return Colors.green;
      case 'Processing':
        return Colors.orange;
    }
    return context.bookColors.mutedText;
  }

  Future<void> _swapStatus(int idx) async {
    var o = widget.orders[idx];
    final statusIndex = Order.statuses.indexOf(o.status);
    if (statusIndex < 0 || statusIndex >= Order.statuses.length - 1) {
      _toast('No further status change is available.');
      return;
    }
    final opts = [Order.statuses[statusIndex + 1]];
    var picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.bookColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Change status — ${o.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...opts.map(
              (s) => ListTile(
                leading: Icon(Icons.circle, size: 12, color: _statClr(s)),
                title: Text(s),
                trailing: o.status == s
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => Navigator.pop(context, s),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await widget.repository.setOrderStatus(o.id, picked);
    } catch (_) {
      if (mounted) _toast('Status could not be saved. Try again.');
      return;
    }
    if (mounted) _toast('${o.id} → $picked');
  }

  void _details(String id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SizedBox(
        height: MediaQuery.sizeOf(sheet).height * .8,
        child: StreamBuilder<List<Order>>(
          stream: widget.repository.watchOrders('', admin: true),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Center(child: Text('Order could not be loaded.'));
            final order = (snapshot.data ?? widget.orders)
                .where((o) => o.id == id)
                .firstOrNull;
            if (order == null)
              return const Center(child: Text('Order no longer exists.'));
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(order.id, style: Theme.of(context).textTheme.titleLarge),
                Text('Customer: ${order.userId}'),
                Text(order.shippingAddress),
                if (order.deliveryContact != null)
                  Text(
                    'Delivery contact: ${order.deliveryContact!.name} • ${order.deliveryContact!.phone}',
                  ),
                Text('Status: ${order.status}'),
                Text(
                  'Placed: ${order.date.toLocal().toString().split(".").first}',
                ),
                const Divider(),
                for (final item in order.items)
                  ListTile(
                    title: Text(item.book.title),
                    subtitle: Text(
                      '${item.quantity} × \$${item.book.price.toStringAsFixed(2)}',
                    ),
                    trailing: Text(
                      '\$${(item.book.price * item.quantity).toStringAsFixed(2)}',
                    ),
                  ),
                const Divider(),
                Text('Total: \$${order.total.toStringAsFixed(2)}'),
                if (order.promoCode.isNotEmpty)
                  Text('Promotion: ${order.promoCode}'),
                Text('Payment: ${order.paymentLabel}'),
                if (order.cardLabel != null) Text(order.cardLabel!),
              ],
            );
          },
        ),
      ),
    );
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    var items = _vis;

    return Scaffold(
      backgroundColor: context.bookColors.adminBackground,
      appBar: AppBar(
        backgroundColor: context.bookColors.adminBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: context.bookColors.text,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Orders',
          style: TextStyle(
            color: context.bookColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filters.length, (idx) {
                  var on = _filterIdx == idx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filterIdx = idx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: on
                              ? context.bookColors.adminPrimary
                              : context.bookColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: on
                                ? context.bookColors.adminPrimary
                                : context.bookColors.border,
                          ),
                        ),
                        child: Text(
                          _filters[idx],
                          style: TextStyle(
                            color: on
                                ? context.bookColors.onPrimary
                                : context.bookColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'No orders here',
                      style: TextStyle(color: context.bookColors.mutedText),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      var o = items[i];
                      var realIdx = widget.orders.indexOf(o);
                      var c = _statClr(o.status);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.bookColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.bookColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _details(o.id),
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('Order details'),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  o.id,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    o.status,
                                    style: TextStyle(
                                      color: c,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${o.shippingAddress} · ${o.items.length} items',
                              style: TextStyle(
                                color: context.bookColors.secondaryText,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _swapStatus(realIdx),
                                  icon: const Icon(Icons.edit, size: 14),
                                  label: const Text(
                                    'Change status',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: context.bookColors.text,
                                    side: BorderSide(
                                      color: context.bookColors.border,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  '\$${o.total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

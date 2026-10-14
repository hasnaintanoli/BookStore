import '../theme/book_theme.dart';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../widgets/book_detail_modal.dart';

class LikedScreen extends StatelessWidget {
  final List<Book> allBooks;
  final List<CartItem> cartItems;
  final Set<String> savedBookIds;
  final Future<void> Function(Book) onAddToCart;
  final Future<void> Function(String) onToggleSave;

  const LikedScreen({
    super.key,
    required this.allBooks,
    required this.cartItems,
    required this.savedBookIds,
    required this.onAddToCart,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final savedBooks = allBooks
        .where((b) => savedBookIds.contains(b.id))
        .toList();

    return Scaffold(
      backgroundColor: context.bookColors.background,
      appBar: AppBar(
        backgroundColor: context.bookColors.background,
        elevation: 0,
        title: Text(
          'Saved Books',
          style: TextStyle(
            color: context.bookColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          CircleAvatar(
            backgroundColor: context.bookColors.surface,
            child: IconButton(
              icon: Icon(
                Icons.shopping_bag_outlined,
                color: context.bookColors.text,
              ),
              onPressed: () => Navigator.pushNamed(context, '/cart'),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: savedBooks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: context.bookColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite_outline,
                        size: 40,
                        color: context.bookColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No saved books yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.bookColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the heart icon on any book while browsing to add it to your reading list.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.bookColors.secondaryText,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: savedBooks.length,
              itemBuilder: (context, index) {
                final book = savedBooks[index];
                return Card(
                  color: context.bookColors.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () => showBookDetailModal(
                      context,
                      book,
                      onAddToCart,
                      onToggleSave,
                      true,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        book.imageUrl,
                        width: 45,
                        height: 65,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 45,
                          height: 65,
                          color: context.bookColors.background,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.menu_book,
                            color: context.bookColors.mutedText,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      book.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${book.author} • \$${book.price.toStringAsFixed(2)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.add_shopping_cart,
                            color: context.bookColors.primary,
                          ),
                          onPressed: () async {
                            try {
                              await onAddToCart(book);
                            } catch (_) {
                              return;
                            }
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added "${book.title}" to cart!'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            try {
                              await onToggleSave(book.id);
                            } catch (_) {}
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

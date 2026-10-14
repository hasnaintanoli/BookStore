import '../theme/book_theme.dart';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../widgets/book_detail_modal.dart';
import 'user_session.dart';

class HomeScreen extends StatefulWidget {
  final List<Book> allBooks;
  final List<CartItem> cartItems;
  final Set<String> savedBookIds;
  final Future<void> Function(Book) onAddToCart;
  final Future<void> Function(String) onToggleSave;

  const HomeScreen({
    super.key,
    required this.allBooks,
    required this.cartItems,
    required this.savedBookIds,
    required this.onAddToCart,
    required this.onToggleSave,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = 'All';
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final String query = searchQuery.toLowerCase();

    List<Book> filteredBooks = widget.allBooks.where((book) {
      final matchesCategory =
          selectedCategory == 'All' || book.category == selectedCategory;

      final matchesSearch =
          book.title.toLowerCase().contains(query) ||
          book.author.toLowerCase().contains(query) ||
          book.category.toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();

    final List<Book> bestsellers = List<Book>.from(widget.allBooks)
      ..sort((a, b) => b.rating.compareTo(a.rating));

    final List<Book> newArrivals = List<Book>.from(widget.allBooks)
      ..sort((a, b) => b.releaseDate.compareTo(a.releaseDate));

    final int cartCount = widget.cartItems.fold(
      0,
      (sum, item) => sum + item.quantity,
    );

    // Logged-in user's name
    final String loggedInUserName = UserSession.name.isNotEmpty
        ? UserSession.name
        : 'Reader';

    return Scaffold(
      backgroundColor: context.bookColors.background,

      appBar: AppBar(
        backgroundColor: context.bookColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good evening',
              style: TextStyle(
                color: context.bookColors.secondaryText,
                fontSize: 13,
              ),
            ),

            // Dynamic logged-in user's name
            Text(
              loggedInUserName,
              style: TextStyle(
                color: context.bookColors.text,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Order notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                backgroundColor: context.bookColors.surface,
                child: IconButton(
                  icon: Icon(
                    Icons.shopping_bag_outlined,
                    color: context.bookColors.text,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/cart');
                  },
                ),
              ),

              if (cartCount > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.bookColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$cartCount',
                      style: TextStyle(
                        color: context.bookColors.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 8),

          CircleAvatar(
            backgroundColor: context.bookColors.surface,
            child: IconButton(
              icon: Icon(Icons.person_outline, color: context.bookColors.text),
              onPressed: () {
                // Open profile
                // If your main_shell handles Profile tab,
                // this can remain as a visual button.
              },
            ),
          ),

          const SizedBox(width: 16),
        ],
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // SEARCH
            // =========================
            TextField(
              onChanged: (val) {
                setState(() {
                  searchQuery = val;
                });
              },

              decoration: InputDecoration(
                hintText: 'Search titles, authors, genres',

                prefixIcon: Icon(
                  Icons.search,
                  color: context.bookColors.mutedText,
                ),

                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: context.bookColors.mutedText,
                        ),
                        onPressed: () {
                          setState(() {
                            searchQuery = '';
                          });
                        },
                      )
                    : null,

                filled: true,
                fillColor: context.bookColors.surface,

                contentPadding: const EdgeInsets.symmetric(vertical: 12),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // =========================
            // CATEGORIES
            // =========================
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,

              child: Row(
                children:
                    [
                      'All',
                      ...{for (final b in widget.allBooks) b.category},
                    ].map((category) {
                      final isSelected = selectedCategory == category;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),

                        child: FilterChip(
                          selected: isSelected,

                          label: Text(category),

                          backgroundColor: context.bookColors.surface,

                          selectedColor: context.bookColors.primary,
                          checkmarkColor: context.bookColors.onPrimary,

                          labelStyle: TextStyle(
                            color: isSelected
                                ? context.bookColors.onPrimary
                                : context.bookColors.text,
                            fontWeight: FontWeight.w500,
                          ),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),

                          onSelected: (_) {
                            setState(() {
                              selectedCategory = category;
                            });
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // =========================
            // POPULAR BOOKS
            // =========================
            _buildSectionHeader('Popular Books (${filteredBooks.length})'),

            const SizedBox(height: 12),

            SizedBox(
              height: 250,

              child: filteredBooks.isEmpty
                  ? const Center(child: Text('No books matched your criteria'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,

                      physics: const BouncingScrollPhysics(),

                      itemCount: filteredBooks.length,

                      itemBuilder: (context, index) {
                        final book = filteredBooks[index];

                        final isSaved = widget.savedBookIds.contains(book.id);

                        return _buildBookCard(book, isSaved);
                      },
                    ),
            ),

            const SizedBox(height: 20),

            // =========================
            // BESTSELLERS
            // =========================
            _buildSectionHeader('Bestsellers'),

            const SizedBox(height: 12),

            SizedBox(
              height: 250,

              child: bestsellers.isEmpty
                  ? const Center(child: Text('No books matched your criteria'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,

                      physics: const BouncingScrollPhysics(),

                      itemCount: bestsellers.length,

                      itemBuilder: (context, index) {
                        final book = bestsellers[index];

                        final isSaved = widget.savedBookIds.contains(book.id);

                        return _buildBookCard(book, isSaved);
                      },
                    ),
            ),

            const SizedBox(height: 20),

            // =========================
            // NEW ARRIVALS
            // =========================
            _buildSectionHeader('New Arrivals'),

            const SizedBox(height: 12),

            SizedBox(
              height: 250,

              child: newArrivals.isEmpty
                  ? const Center(child: Text('No books matched your criteria'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,

                      physics: const BouncingScrollPhysics(),

                      itemCount: newArrivals.length,

                      itemBuilder: (context, index) {
                        final book = newArrivals[index];

                        final isSaved = widget.savedBookIds.contains(book.id);

                        return _buildBookCard(book, isSaved);
                      },
                    ),
            ),

            const SizedBox(height: 20),

            // =========================
            // CURATED SELECTION
            // =========================
            _buildSectionHeader('Curated Selection'),

            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: widget.allBooks.length,

              itemBuilder: (context, index) {
                final book = widget.allBooks[index];

                final isSaved = widget.savedBookIds.contains(book.id);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),

                  padding: const EdgeInsets.all(8),

                  decoration: BoxDecoration(
                    color: context.bookColors.surface,

                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: ListTile(
                    onTap: () {
                      showBookDetailModal(
                        context,
                        book,
                        widget.onAddToCart,
                        widget.onToggleSave,
                        isSaved,
                      );
                    },

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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                    subtitle: Text(
                      '${book.author} • \$${book.price.toStringAsFixed(2)}',
                    ),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.favorite : Icons.favorite_border,

                            color: isSaved
                                ? Colors.red
                                : context.bookColors.mutedText,
                          ),

                          onPressed: () async {
                            try {
                              await widget.onToggleSave(book.id);
                            } catch (_) {}
                          },
                        ),

                        IconButton(
                          icon: Icon(
                            Icons.add_shopping_cart,
                            color: context.bookColors.primary,
                          ),

                          onPressed: () async {
                            try {
                              await widget.onAddToCart(book);
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
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // SECTION HEADER
  // =========================
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: context.bookColors.text,
      ),
    );
  }

  // =========================
  // BOOK CARD
  // =========================
  Widget _buildBookCard(Book book, bool isSaved) {
    return Container(
      width: 140,

      margin: const EdgeInsets.only(right: 14),

      child: GestureDetector(
        onTap: () {
          showBookDetailModal(
            context,
            book,
            widget.onAddToCart,
            widget.onToggleSave,
            isSaved,
          );
        },

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),

                  child: Image.network(
                    book.imageUrl,
                    height: 160,
                    width: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 160,
                      width: 140,
                      color: context.bookColors.background,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.menu_book,
                        color: context.bookColors.mutedText,
                        size: 32,
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 6,
                  right: 6,

                  child: GestureDetector(
                    onTap: () async {
                      try {
                        await widget.onToggleSave(book.id);
                      } catch (_) {}
                    },

                    child: Container(
                      padding: const EdgeInsets.all(4),

                      decoration: BoxDecoration(
                        color: context.bookColors.surface,
                        shape: BoxShape.circle,
                      ),

                      child: Icon(
                        isSaved ? Icons.favorite : Icons.favorite_border,

                        color: isSaved
                            ? Colors.red
                            : context.bookColors.secondaryText,

                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,

              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),

            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,

              style: TextStyle(
                color: context.bookColors.secondaryText,
                fontSize: 10,
              ),
            ),

            Text(
              '\$${book.price.toStringAsFixed(2)}',

              style: TextStyle(
                color: context.bookColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import '../../theme/book_theme.dart';
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/store_repository.dart';
import '../../widgets/book_editor_sheet.dart';
import '../../services/book_cover_service.dart';
import '../user_session.dart';

class ManageBooksScreen extends StatefulWidget {
  final List<Book> allBooks;
  final StoreRepository repository;

  const ManageBooksScreen({
    super.key,
    required this.allBooks,
    required this.repository,
  });

  @override
  State<ManageBooksScreen> createState() => _ManageBooksScreenState();
}

class _ManageBooksScreenState extends State<ManageBooksScreen> {
  final _searchCtl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => recoverCover());
  }

  Future<void> recoverCover() async {
    final ownerUid = UserSession.uid;
    try {
      final cover = await BookCoverService().recover();
      if (!mounted ||
          cover == null ||
          UserSession.uid != ownerUid ||
          !UserSession.isAdmin)
        return;
      _snack('Picture recovered. Enter the book details to save it.');
      await _openForm(initialCover: cover);
    } catch (error) {
      if (mounted)
        _snack(
          error is BookCoverException
              ? error.message
              : 'Choose the book picture again.',
        );
    }
  }

  List<Book> get _vis {
    if (_q.isEmpty) return widget.allBooks;
    var needle = _q.toLowerCase();
    var out = <Book>[];
    var i = 0;
    while (i < widget.allBooks.length) {
      var b = widget.allBooks[i];
      var t = b.title.toLowerCase();
      var a = b.author.toLowerCase();
      var g = b.category.toLowerCase();
      if (t.contains(needle) || a.contains(needle) || g.contains(needle)) {
        out.add(b);
      }
      i++;
    }
    return out;
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _openForm({
    Book? existing,
    int? idx,
    PickedBookCover? initialCover,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => BookEditorSheet(
        repository: widget.repository,
        existing: existing,
        initialCover: initialCover,
      ),
    );
    if (saved == true && mounted)
      _snack(existing == null ? 'Book added' : 'Book updated');
  }

  Color _colorFor(Book b) {
    var palette = [
      Colors.blue,
      Colors.red,
      Colors.teal,
      Colors.brown,
      Colors.indigo,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.cyan,
      Colors.pink,
    ];
    return palette[b.id.hashCode.abs() % palette.length];
  }

  void _confirmDelete(int idx) {
    var book = widget.allBooks[idx];
    var deleting = false;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete book?'),
        content: Text('Remove "${book.title}" from catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (deleting) return;
              deleting = true;
              try {
                await widget.repository.deleteBook(book.id);
              } catch (_) {
                if (mounted) _snack('Book could not be deleted. Try again.');
                return;
              } finally {
                deleting = false;
              }
              if (!mounted || !dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              _snack('Book deleted');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _snack(String m) {
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
          'Books',
          style: TextStyle(
            color: context.bookColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: Icon(
                Icons.add,
                size: 16,
                color: context.bookColors.onPrimary,
              ),
              label: Text(
                'Add',
                style: TextStyle(
                  color: context.bookColors.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.bookColors.adminPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: context.bookColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.bookColors.border),
              ),
              child: TextField(
                controller: _searchCtl,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search catalog',
                  hintStyle: TextStyle(
                    color: context.bookColors.mutedText,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: context.bookColors.mutedText,
                    size: 20,
                  ),
                  suffixIcon: null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'No books found',
                      style: TextStyle(color: context.bookColors.mutedText),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      var b = items[i];
                      var realIdx = widget.allBooks.indexOf(b);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.bookColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.bookColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _colorFor(b),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  b.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) => Center(
                                    child: Text(
                                      b.title
                                          .substring(
                                            0,
                                            b.title.length < 2
                                                ? b.title.length
                                                : 2,
                                          )
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${b.author} Â· \$${b.price.toStringAsFixed(2)} Â· ${b.category}',
                                    style: TextStyle(
                                      color: context.bookColors.secondaryText,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                size: 18,
                                color: context.bookColors.mutedText,
                              ),
                              onPressed: () =>
                                  _openForm(existing: b, idx: realIdx),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: context.bookColors.mutedText,
                              ),
                              onPressed: () => _confirmDelete(realIdx),
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

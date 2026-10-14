import '../theme/book_theme.dart';
import 'dart:async';
import '../services/review_service.dart';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../screens/user_session.dart';

void showBookDetailModal(
  BuildContext context,
  Book book,
  Future<void> Function(Book) onAddToCart,
  Future<void> Function(String) onToggleSave,
  bool isSaved,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return _BookDetailSheet(
        book: book,
        onAddToCart: onAddToCart,
        onToggleSave: onToggleSave,
        isSaved: isSaved,
      );
    },
  );
}

class _BookDetailSheet extends StatefulWidget {
  final Book book;
  final Future<void> Function(Book) onAddToCart;
  final Future<void> Function(String) onToggleSave;
  final bool isSaved;

  const _BookDetailSheet({
    required this.book,
    required this.onAddToCart,
    required this.onToggleSave,
    required this.isSaved,
  });

  @override
  State<_BookDetailSheet> createState() => _BookDetailSheetState();
}

class _BookDetailSheetState extends State<_BookDetailSheet> {
  late bool isSaved;
  List<Review> reviews = [];
  StreamSubscription<List<Review>>? subscription;
  bool loadingReviews = true;
  String? reviewError;
  bool liking = false;

  @override
  void initState() {
    super.initState();
    isSaved = widget.isSaved;
    subscription = ReviewService.instance
        .watch(widget.book.id, UserSession.uid)
        .listen(
          (value) {
            if (!mounted) return;
            setState(() {
              reviews = value;
              loadingReviews = false;
              reviewError = null;
            });
          },
          onError: (Object _) {
            if (mounted)
              setState(() {
                loadingReviews = false;
                reviewError = 'Reviews could not be loaded.';
              });
          },
        );
  }

  double get averageRating {
    if (reviews.isEmpty) return widget.book.rating;
    final sum = reviews.fold<double>(0, (s, r) => s + r.rating);
    return sum / reviews.length;
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleLike(Review review) async {
    if (liking) return;
    liking = true;
    try {
      await ReviewService.instance.setLiked(
        widget.book.id,
        review.id,
        !review.likedByMe,
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Like could not be saved. Try again.')),
        );
    } finally {
      liking = false;
    }
  }

  void _showWriteReviewSheet() {
    final own = reviews.where((r) => r.userId == UserSession.uid).firstOrNull;
    double myRating = own?.rating ?? 5;
    final commentController = TextEditingController(text: own?.comment ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Write a review',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (i) {
                      final filled = i < myRating;
                      return IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          filled ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 30,
                        ),
                        onPressed: () => setSheetState(() => myRating = i + 1),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    maxLength: 2000,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share what you thought about this book...',
                      filled: true,
                      fillColor: context.bookColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final text = commentController.text.trim();
                              if (text.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please write a few words first.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => saving = true);
                              try {
                                await ReviewService.instance.save(
                                  widget.book.id,
                                  myRating,
                                  text,
                                );
                              } catch (_) {
                                if (ctx.mounted) {
                                  setSheetState(() => saving = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Review could not be saved. Try again.',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              if (!ctx.mounted || !mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Thanks for your review!'),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.bookColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Submit Review',
                        style: TextStyle(
                          color: context.bookColors.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.bookColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    book.imageUrl,
                    width: 90,
                    height: 130,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 90,
                      height: 130,
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By ${book.author}',
                        style: TextStyle(
                          color: context.bookColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          Text(
                            ' ${averageRating.toStringAsFixed(1)} ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '(${reviews.length} reviews)',
                            style: TextStyle(
                              color: context.bookColors.mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${book.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.bookColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Synopsis',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              book.description,
              style: TextStyle(color: context.bookColors.text, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await widget.onToggleSave(book.id);
                    } catch (_) {
                      return;
                    }
                    if (mounted) setState(() => isSaved = !isSaved);
                  },
                  icon: Icon(
                    isSaved ? Icons.favorite : Icons.favorite_border,
                    color: Colors.red,
                  ),
                  label: Text(isSaved ? 'Saved' : 'Save'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await widget.onAddToCart(book);
                      } catch (_) {
                        return;
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added "${book.title}" to cart!'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.bookColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: Icon(
                      Icons.shopping_bag_outlined,
                      color: context.bookColors.onPrimary,
                    ),
                    label: Text(
                      'Add to Cart',
                      style: TextStyle(
                        color: context.bookColors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ratings & reviews
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ratings & Reviews',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                TextButton.icon(
                  onPressed: _showWriteReviewSheet,
                  icon: Icon(
                    Icons.rate_review_outlined,
                    size: 18,
                    color: context.bookColors.primary,
                  ),
                  label: Text(
                    'Write',
                    style: TextStyle(color: context.bookColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (loadingReviews) const LinearProgressIndicator(),
            if (reviewError != null) Text(reviewError!),
            if (!loadingReviews && reviews.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No reviews yet. Be the first to review this book!',
                  style: TextStyle(color: context.bookColors.secondaryText),
                ),
              )
            else
              ...reviews.map(_buildReviewTile),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewTile(Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bookColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: context.bookColors.primary,
                child: Text(
                  review.user.isNotEmpty ? review.user[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: context.bookColors.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                review.user,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            review.comment,
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _toggleLike(review),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  review.likedByMe ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 15,
                  color: review.likedByMe
                      ? context.bookColors.primary
                      : context.bookColors.mutedText,
                ),
                const SizedBox(width: 4),
                Text(
                  'Helpful (${review.likes})',
                  style: TextStyle(
                    fontSize: 12,
                    color: review.likedByMe
                        ? context.bookColors.primary
                        : context.bookColors.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

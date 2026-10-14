import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/store_repository.dart';
import '../services/book_cover_service.dart';
import '../screens/user_session.dart';

class BookEditorSheet extends StatefulWidget {
  const BookEditorSheet({
    super.key,
    required this.repository,
    this.existing,
    this.initialCover,
  });
  final StoreRepository repository;
  final Book? existing;
  final PickedBookCover? initialCover;
  @override
  State<BookEditorSheet> createState() => _BookEditorSheetState();
}

class _BookEditorSheetState extends State<BookEditorSheet> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title,
      author,
      price,
      genre,
      cover,
      description;
  late DateTime releaseDate;
  final coverService = BookCoverService();
  late final String ownerUid;
  PickedBookCover? selectedCover;
  String? uploadedCoverUrl;
  bool saving = false, picking = false;
  String saveLabel = 'Saving...';
  @override
  void initState() {
    super.initState();
    ownerUid = UserSession.uid;
    selectedCover = widget.initialCover;
    final b = widget.existing;
    title = TextEditingController(text: b?.title ?? '');
    author = TextEditingController(text: b?.author ?? '');
    price = TextEditingController(text: b?.price.toStringAsFixed(2) ?? '');
    genre = TextEditingController(text: b?.category ?? '');
    cover = TextEditingController(text: b?.imageUrl ?? '');
    description = TextEditingController(text: b?.description ?? '');
    releaseDate = b?.releaseDate ?? DateTime.now();
  }

  @override
  void dispose() {
    for (final c in [title, author, price, genre, cover, description]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget input(
    TextEditingController c,
    String label,
    int max, {
    int lines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      enabled: !saving && !picking,
      maxLength: max,
      maxLines: lines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator:
          validator ??
          (value) => value == null || value.trim().isEmpty ? 'Required' : null,
    ),
  );
  Future<void> submit() async {
    if (saving || picking || !form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      if (UserSession.uid != ownerUid || !UserSession.isAdmin) {
        throw const BookCoverException(
          'Account changed. Open the book editor again.',
        );
      }
      if (selectedCover != null && uploadedCoverUrl == null) {
        setState(() => saveLabel = 'Uploading picture...');
        uploadedCoverUrl = await coverService.upload(selectedCover!);
        if (!mounted) return;
        setState(() => saveLabel = 'Saving book...');
      }
      if (UserSession.uid != ownerUid || !UserSession.isAdmin) {
        throw const BookCoverException(
          'Account changed. Open the book editor again.',
        );
      }
      await widget.repository.saveBook(
        Book(
          id:
              widget.existing?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          title: title.text.trim(),
          author: author.text.trim(),
          price: double.parse(price.text.trim()),
          rating: widget.existing?.rating ?? 0,
          category: genre.text.trim(),
          imageUrl: uploadedCoverUrl ?? cover.text.trim(),
          description: description.text.trim(),
          releaseDate: releaseDate,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is BookCoverException
                  ? error.message
                  : 'Book could not be saved. Check the details and connection.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> pickCover() async {
    if (saving || picking) return;
    setState(() => picking = true);
    try {
      final picked = await coverService.pick();
      if (!mounted || UserSession.uid != ownerUid) return;
      if (picked != null)
        setState(() {
          selectedCover = picked;
          uploadedCoverUrl = null;
        });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is BookCoverException
                  ? error.message
                  : 'Picture could not be selected. Please retry.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Widget coverSelection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (selectedCover != null || cover.text.trim().isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: selectedCover != null
                ? Image.memory(
                    selectedCover!.bytes,
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stack) => const SizedBox(
                      height: 80,
                      child: Center(child: Text('Choose another image.')),
                    ),
                  )
                : Image.network(
                    cover.text.trim(),
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stack) => const SizedBox(
                      height: 80,
                      child: Icon(Icons.image_outlined),
                    ),
                  ),
          ),
        ),
      OutlinedButton.icon(
        onPressed: saving || picking ? null : pickCover,
        icon: const Icon(Icons.photo_library_outlined),
        label: Text(
          picking
              ? 'Opening gallery...'
              : selectedCover == null
              ? 'Pick book picture'
              : 'Change picture',
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 6, bottom: 12),
        child: Text('JPG, PNG or WebP • Up to 20 MB'),
      ),
      if (selectedCover != null)
        TextButton(
          onPressed: saving || picking
              ? null
              : () => setState(() {
                  selectedCover = null;
                  uploadedCoverUrl = null;
                }),
          child: const Text('Use image URL instead'),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && !picking,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.existing == null ? 'Add book' : 'Edit book',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close book editor',
                      onPressed: saving || picking
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                input(title, 'Title', 300),
                input(author, 'Author', 200),
                input(
                  price,
                  'Price',
                  12,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    final n = double.tryParse(v);
                    return !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v) ||
                            n == null ||
                            !n.isFinite ||
                            n > 100000
                        ? 'Enter a price from 0 to 100000 with up to two decimals'
                        : null;
                  },
                ),
                input(genre, 'Genre', 100),
                coverSelection(),
                if (selectedCover == null)
                  input(
                    cover,
                    'Cover image URL',
                    2000,
                    keyboard: TextInputType.url,
                    validator: (value) {
                      final uri = Uri.tryParse(value?.trim() ?? '');
                      return uri == null ||
                              uri.scheme != 'https' ||
                              uri.host.isEmpty
                          ? 'Enter an HTTPS image URL'
                          : null;
                    },
                  ),
                input(
                  description,
                  'Description',
                  20000,
                  lines: 4,
                  validator: (_) => null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Release date'),
                  subtitle: Text(
                    releaseDate.toIso8601String().split('T').first,
                  ),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: saving || picking
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: releaseDate,
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2100),
                          );
                          if (date != null && mounted)
                            setState(() => releaseDate = date);
                        },
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: saving || picking ? null : submit,
                  child: Text(saving ? saveLabel : 'Save book'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

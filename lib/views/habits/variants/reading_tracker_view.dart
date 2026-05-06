import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/core/utils/uuid_generator.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/services/google_books_service.dart';

enum _ReadingLogMode { time, pages, books }

const String _readingYearlyGoalDocId = '_reading_yearly_goal';
const int _defaultReadingYearlyGoal = 12;

class _ReadingBook {
  final String bookId;
  final String title;
  final String author;
  final String? coverUrl;
  final int? pageCount;
  final String? genre;
  final String? blurb;
  final int currentPage;
  final String status;
  final DateTime? completedAt;

  const _ReadingBook({
    required this.bookId,
    required this.title,
    required this.author,
    this.coverUrl,
    this.pageCount,
    this.genre,
    this.blurb,
    this.currentPage = 0,
    this.status = 'currently_reading',
    this.completedAt,
  });

  factory _ReadingBook.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return _ReadingBook(
      bookId: data['bookId'] as String? ?? doc.id,
      title: data['title'] as String? ?? 'Untitled',
      author: data['author'] as String? ?? 'Unknown',
      coverUrl: data['coverUrl'] as String?,
      pageCount: (data['pageCount'] as num?)?.toInt(),
      genre: data['genre'] as String?,
      blurb: data['blurb'] as String?,
      currentPage: (data['currentPage'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'currently_reading',
      completedAt: _asDateTime(data['completedAt']),
    );
  }

  double get progress {
    final pages = pageCount;
    if (pages == null || pages <= 0) return 0;
    return (currentPage / pages).clamp(0.0, 1.0).toDouble();
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _ReadingSession {
  final String logId;
  final String? bookId;
  final DateTime occurredAt;
  final int durationMin;
  final int pagesRead;
  final String? note;
  final String mode;

  const _ReadingSession({
    required this.logId,
    this.bookId,
    required this.occurredAt,
    this.durationMin = 0,
    this.pagesRead = 0,
    this.note,
    this.mode = 'time',
  });

  factory _ReadingSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return _ReadingSession(
      logId: data['logId'] as String? ?? doc.id,
      bookId: data['bookId'] as String?,
      occurredAt: _asDateTime(data['occurredAt'] ?? data['ts']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      durationMin: (data['durationMin'] as num?)?.toInt() ??
          ((data['durationSec'] as num?)?.toInt() ?? 0) ~/ 60,
      pagesRead: (data['pagesRead'] as num?)?.toInt() ?? 0,
      note: data['note'] as String?,
      mode: data['readingMode'] as String? ?? data['type'] as String? ?? 'time',
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

final _readingBooksProvider = StreamProvider<List<_ReadingBook>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const <_ReadingBook>[]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('books')
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .where((doc) =>
              doc.id != _readingYearlyGoalDocId &&
              doc.data()['docType'] != 'reading_goal')
          .map(_ReadingBook.fromDoc)
          .toList());
});

final _readingYearlyGoalProvider = StreamProvider<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(_defaultReadingYearlyGoal);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('books')
      .doc(_readingYearlyGoalDocId)
      .snapshots()
      .map((snap) {
    final goal = (snap.data()?['yearlyGoal'] as num?)?.round();
    if (goal == null || goal <= 0) return _defaultReadingYearlyGoal;
    return goal;
  });
});

final _readingSessionsProvider =
    StreamProvider.family<List<_ReadingSession>, String>((ref, habitId) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const <_ReadingSession>[]);

  final now = DateTime.now();
  final startOfYear = DateTime(now.year);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('habit_logs')
      .where('habitId', isEqualTo: habitId)
      .where('occurredAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
      .snapshots()
      .map((snap) {
    final sessions = snap.docs
        .where((doc) => doc.data()['logType'] == 'good')
        .map(_ReadingSession.fromDoc)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return sessions;
  });
});

class ReadingTrackerView extends ConsumerStatefulWidget {
  final HabitModel habit;

  const ReadingTrackerView({super.key, required this.habit});

  @override
  ConsumerState<ReadingTrackerView> createState() => _ReadingTrackerViewState();
}

class _ReadingTrackerViewState extends ConsumerState<ReadingTrackerView> {
  _ReadingLogMode _mode = _ReadingLogMode.time;
  bool _addingBook = false;

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(_readingBooksProvider);
    final yearlyGoalAsync = ref.watch(_readingYearlyGoalProvider);
    final sessionsAsync = ref.watch(_readingSessionsProvider(widget.habit.id));
    final streakAsync = ref.watch(streakByIdProvider(widget.habit.id));

    return booksAsync.when(
      loading: () => const _Loading(),
      error: (e, __) => _Error(message: e.toString()),
      data: (books) => yearlyGoalAsync.when(
        loading: () => const _Loading(),
        error: (e, __) => _Error(message: e.toString()),
        data: (yearlyGoal) => sessionsAsync.when(
          loading: () => const _Loading(),
          error: (e, __) => _Error(message: e.toString()),
          data: (sessions) => streakAsync.when(
            loading: () => const _Loading(),
            error: (e, __) => _Error(message: e.toString()),
            data: (streak) {
              final currentBooks = books
                  .where((book) => book.status == 'currently_reading')
                  .toList();
              final year = DateTime.now().year;
              final completedThisYear = books
                  .where((book) =>
                      book.status == 'completed' &&
                      (book.completedAt?.year ?? year) == year)
                  .length;
              final todayMinutes = _todayMinutes(sessions);
              final todayPages = _todayPages(sessions);

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCard(
                      todayMinutes: todayMinutes,
                      todayPages: todayPages,
                      streakDays: streak?.currentCount ?? 0,
                      completedBooks: completedThisYear,
                      yearlyGoal: yearlyGoal,
                      onEditGoal: () => _showYearlyGoalSheet(yearlyGoal),
                    ),
                    const SizedBox(height: 16),
                    _ModeSelector(
                      selected: _mode,
                      onChanged: (mode) => setState(() => _mode = mode),
                    ),
                    const SizedBox(height: 14),
                    _PrimaryActions(
                      mode: _mode,
                      hasBooks: currentBooks.isNotEmpty,
                      onAddBook: _addingBook ? null : _showAddBookSheet,
                      onLog: () => _showSessionSheet(currentBooks),
                    ),
                    const SizedBox(height: 22),
                    _SectionHeader(
                      title: 'Currently Reading',
                      actionLabel: 'Add Book',
                      onAction: _addingBook ? null : _showAddBookSheet,
                    ),
                    const SizedBox(height: 10),
                    _BookShelf(
                      books: currentBooks,
                      onLog: (book) =>
                          _showSessionSheet(currentBooks, book: book),
                    ),
                    const SizedBox(height: 22),
                    _SectionHeader(title: 'Recent Sessions'),
                    const SizedBox(height: 10),
                    _SessionList(sessions: sessions.take(5).toList()),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  int _todayMinutes(List<_ReadingSession> sessions) {
    final today = _dateStr(DateTime.now());
    return sessions
        .where((s) => _dateStr(s.occurredAt) == today)
        .fold<int>(0, (total, s) => total + s.durationMin);
  }

  int _todayPages(List<_ReadingSession> sessions) {
    final today = _dateStr(DateTime.now());
    return sessions
        .where((s) => _dateStr(s.occurredAt) == today)
        .fold<int>(0, (total, s) => total + s.pagesRead);
  }

  Future<void> _showAddBookSheet() async {
    final titleController = TextEditingController();
    final authorController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottom = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(24, 10, 24, 24 + bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LiquidSheetHandle(),
                    const SizedBox(height: 16),
                    const Text(
                      'Add Book',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LiquidTextField(
                      hint: 'Title',
                      prefixIcon: Icons.auto_stories_rounded,
                      controller: titleController,
                    ),
                    const SizedBox(height: 12),
                    LiquidTextField(
                      hint: 'Author',
                      prefixIcon: Icons.person_rounded,
                      controller: authorController,
                    ),
                    const SizedBox(height: 20),
                    LiquidButton(
                      label: _addingBook ? 'Looking up...' : 'Lookup & Add',
                      color: kAmber,
                      onTap: _addingBook
                          ? null
                          : () async {
                              setSheetState(() => _addingBook = true);
                              setState(() => _addingBook = true);
                              try {
                                await _addBook(
                                  titleController.text,
                                  authorController.text,
                                );
                                if (mounted && sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              } catch (e) {
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text('Book lookup failed: $e'),
                                      backgroundColor: kCoral,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _addingBook = false);
                                }
                                if (sheetContext.mounted) {
                                  setSheetState(() => _addingBook = false);
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    authorController.dispose();
  }

  Future<void> _showYearlyGoalSheet(int currentGoal) async {
    final goalController = TextEditingController(text: currentGoal.toString());

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(24, 10, 24, 24 + bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LiquidSheetHandle(),
                const SizedBox(height: 16),
                const Text(
                  'Yearly Goal',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 16),
                LiquidTextField(
                  hint: 'Books this year',
                  prefixIcon: Icons.track_changes_rounded,
                  controller: goalController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                LiquidButton(
                  label: 'Save Goal',
                  color: kAmber,
                  onTap: () async {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    final goal = int.tryParse(goalController.text.trim()) ?? 0;
                    if (uid == null) return;
                    if (goal <= 0) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a goal above zero.'),
                          backgroundColor: kCoral,
                        ),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('books')
                        .doc(_readingYearlyGoalDocId)
                        .set({
                      'docType': 'reading_goal',
                      'yearlyGoal': goal,
                      'updatedAt': FieldValue.serverTimestamp(),
                      'schemaVersion': 1,
                    }, SetOptions(merge: true));

                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    goalController.dispose();
  }

  Future<void> _addBook(String title, String author) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    if (title.trim().isEmpty) throw Exception('Book title is required.');

    final result = await GoogleBooksService().lookupBook(
      title: title,
      author: author,
    );
    final bookId =
        result?.volumeId.isNotEmpty == true ? result!.volumeId : generateId();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('books')
        .doc(bookId)
        .set({
      'bookId': bookId,
      'title': result?.title ?? title.trim(),
      'author': result?.author ??
          (author.trim().isNotEmpty ? author.trim() : 'Unknown'),
      if (result?.coverUrl != null) 'coverUrl': result!.coverUrl,
      if (result?.pageCount != null) 'pageCount': result!.pageCount,
      if (result?.genre != null) 'genre': result!.genre,
      if (result?.blurb != null) 'blurb': result!.blurb,
      'currentPage': 0,
      'status': 'currently_reading',
      'source': result == null ? 'manual' : 'google_books',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result == null
              ? 'Book added without Google Books metadata.'
              : 'Book added from Google Books.'),
        ),
      );
    }
  }

  Future<void> _showSessionSheet(
    List<_ReadingBook> books, {
    _ReadingBook? book,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReadingSessionSheet(
        habit: widget.habit,
        mode: _mode,
        books: books,
        initialBook: book,
      ),
    );
  }

  static String _dateStr(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _HeroCard extends StatelessWidget {
  final int todayMinutes;
  final int todayPages;
  final int streakDays;
  final int completedBooks;
  final int yearlyGoal;
  final VoidCallback onEditGoal;

  const _HeroCard({
    required this.todayMinutes,
    required this.todayPages,
    required this.streakDays,
    required this.completedBooks,
    required this.yearlyGoal,
    required this.onEditGoal,
  });

  @override
  Widget build(BuildContext context) {
    final yearlyProgress = yearlyGoal <= 0
        ? 0.0
        : (completedBooks / yearlyGoal).clamp(0.0, 1.0).toDouble();

    return LiquidCard(
      radius: 28,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CustomPaint(
              painter: _RingPainter(progress: yearlyProgress),
              child: Center(
                child: Text(
                  '$completedBooks/$yearlyGoal',
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reading',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Yearly book goal',
                        style: TextStyle(
                          color: kSub.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Edit yearly goal',
                      child: GestureDetector(
                        onTap: onEditGoal,
                        child: const Icon(
                          Icons.edit_rounded,
                          color: kAmber,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(
                      icon: Icons.timer_rounded,
                      label: '${todayMinutes}m today',
                    ),
                    _MetricChip(
                      icon: Icons.menu_book_rounded,
                      label: '$todayPages pages',
                    ),
                    _MetricChip(
                      icon: Icons.local_fire_department_rounded,
                      label: '$streakDays day streak',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;
    const strokeWidth = 9.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = kAmber.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = kAmber
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: kAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kAmber, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: kInk,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final _ReadingLogMode selected;
  final ValueChanged<_ReadingLogMode> onChanged;

  const _ModeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _ReadingLogMode.values.map((mode) {
        final active = mode == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? kAmber.withValues(alpha: 0.18)
                      : kWhite.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active
                        ? kAmber.withValues(alpha: 0.42)
                        : kWhite.withValues(alpha: 0.75),
                  ),
                ),
                child: Text(
                  switch (mode) {
                    _ReadingLogMode.time => 'Time',
                    _ReadingLogMode.pages => 'Pages',
                    _ReadingLogMode.books => 'Books',
                  },
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? kInk : kSub,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  final _ReadingLogMode mode;
  final bool hasBooks;
  final VoidCallback? onAddBook;
  final VoidCallback onLog;

  const _PrimaryActions({
    required this.mode,
    required this.hasBooks,
    required this.onAddBook,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LiquidButton(
            label: switch (mode) {
              _ReadingLogMode.time => 'Log Time',
              _ReadingLogMode.pages => 'Log Pages',
              _ReadingLogMode.books => 'Finish Book',
            },
            color: kAmber,
            leading: const Icon(Icons.add_rounded, color: Colors.white),
            onTap: hasBooks || mode == _ReadingLogMode.time ? onLog : onAddBook,
          ),
        ),
        const SizedBox(width: 12),
        _IconButton(
          icon: Icons.library_add_rounded,
          tooltip: 'Add book',
          onTap: onAddBook,
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: kAmber.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kAmber.withValues(alpha: 0.24)),
          ),
          child: Icon(icon, color: kAmber),
        ),
      ),
    );
  }
}

class _BookShelf extends StatelessWidget {
  final List<_ReadingBook> books;
  final ValueChanged<_ReadingBook> onLog;

  const _BookShelf({required this.books, required this.onLog});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return LiquidCard(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Add a book to start your currently-reading shelf.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kSub.withValues(alpha: 0.72),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      children: books
          .map((book) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BookCard(book: book, onLog: () => onLog(book)),
              ))
          .toList(),
    );
  }
}

class _BookCard extends StatelessWidget {
  final _ReadingBook book;
  final VoidCallback onLog;

  const _BookCard({required this.book, required this.onLog});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cover(url: book.coverUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: kSub.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (book.genre != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    book.genre!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: book.progress,
                    minHeight: 8,
                    color: kAmber,
                    backgroundColor: kAmber.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  book.pageCount == null
                      ? '${book.currentPage} pages logged'
                      : '${book.currentPage} / ${book.pageCount} pages',
                  style: TextStyle(
                    color: kSub.withValues(alpha: 0.68),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (book.blurb != null && book.blurb!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    book.blurb!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: kInk.withValues(alpha: 0.62),
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _SmallLogButton(onTap: onLog),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String? url;

  const _Cover({this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 82,
      decoration: BoxDecoration(
        color: kAmber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? const Icon(Icons.auto_stories_rounded, color: kAmber)
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.auto_stories_rounded, color: kAmber),
            ),
    );
  }
}

class _SmallLogButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SmallLogButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: kAmber.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.add_rounded, color: kAmber),
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<_ReadingSession> sessions;

  const _SessionList({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return LiquidCard(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No reading sessions logged this year.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kSub.withValues(alpha: 0.72),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      children: sessions
          .map((session) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LiquidCard(
                  radius: 18,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.bookmark_added_rounded, color: kAmber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sessionTitle(session),
                              style: const TextStyle(
                                color: kInk,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (session.note?.isNotEmpty == true) ...[
                              const SizedBox(height: 3),
                              Text(
                                session.note!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: kSub.withValues(alpha: 0.72),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        _shortDate(session.occurredAt),
                        style: TextStyle(
                          color: kSub.withValues(alpha: 0.62),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  static String _sessionTitle(_ReadingSession session) {
    final parts = <String>[
      if (session.durationMin > 0) '${session.durationMin}m',
      if (session.pagesRead > 0) '${session.pagesRead} pages',
      if (session.mode == 'books') 'book finished',
    ];
    return parts.isEmpty ? 'Reading session' : parts.join(' · ');
  }

  static String _shortDate(DateTime date) =>
      '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

class _ReadingSessionSheet extends ConsumerStatefulWidget {
  final HabitModel habit;
  final _ReadingLogMode mode;
  final List<_ReadingBook> books;
  final _ReadingBook? initialBook;

  const _ReadingSessionSheet({
    required this.habit,
    required this.mode,
    required this.books,
    this.initialBook,
  });

  @override
  ConsumerState<_ReadingSessionSheet> createState() =>
      _ReadingSessionSheetState();
}

class _ReadingSessionSheetState extends ConsumerState<_ReadingSessionSheet> {
  late _ReadingLogMode _mode;
  _ReadingBook? _book;
  final _durationController = TextEditingController();
  final _pagesController = TextEditingController();
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _book = widget.initialBook ??
        (widget.books.isNotEmpty ? widget.books.first : null);
    _durationController.text = _mode == _ReadingLogMode.time ? '20' : '';
  }

  @override
  void dispose() {
    _durationController.dispose();
    _pagesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 10, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const LiquidSheetHandle(),
              const SizedBox(height: 16),
              const Text(
                'Log Reading Session',
                style: TextStyle(
                  color: kInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              _ModeSelector(selected: _mode, onChanged: _setMode),
              if (widget.books.isNotEmpty) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<_ReadingBook>(
                  initialValue: _book,
                  items: widget.books
                      .map((book) => DropdownMenuItem(
                            value: book,
                            child: Text(
                              book.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (book) => setState(() => _book = book),
                  decoration: InputDecoration(
                    labelText: 'Book',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
              if (_mode != _ReadingLogMode.books) ...[
                const SizedBox(height: 14),
                LiquidTextField(
                  hint: 'Duration in minutes',
                  prefixIcon: Icons.timer_rounded,
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                ),
              ],
              if (_mode != _ReadingLogMode.time) ...[
                const SizedBox(height: 14),
                LiquidTextField(
                  hint: _mode == _ReadingLogMode.books
                      ? 'Final page reached'
                      : 'Pages read',
                  prefixIcon: Icons.menu_book_rounded,
                  controller: _pagesController,
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 14),
              LiquidTextField(
                hint: 'Note (optional)',
                prefixIcon: Icons.edit_note_rounded,
                controller: _noteController,
              ),
              const SizedBox(height: 22),
              LiquidButton(
                label: _submitting ? 'Saving...' : 'Save Session',
                color: kAmber,
                onTap: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setMode(_ReadingLogMode mode) {
    setState(() {
      _mode = mode;
      if (_mode == _ReadingLogMode.time && _durationController.text.isEmpty) {
        _durationController.text = '20';
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');

      final durationMin = int.tryParse(_durationController.text.trim()) ?? 0;
      final rawPages = int.tryParse(_pagesController.text.trim()) ?? 0;
      final pagesRead = _mode == _ReadingLogMode.books && _book != null
          ? math.max(0, rawPages - _book!.currentPage)
          : rawPages;
      final note = _noteController.text.trim();

      if (_mode == _ReadingLogMode.time && durationMin <= 0) {
        throw Exception('Enter reading duration.');
      }
      if (_mode == _ReadingLogMode.pages && pagesRead <= 0) {
        throw Exception('Enter pages read.');
      }
      if (_mode == _ReadingLogMode.books && _book == null) {
        throw Exception('Add or choose a book first.');
      }

      final logId = generateId();
      final now = DateTime.now();
      final amount = switch (_mode) {
        _ReadingLogMode.time => durationMin,
        _ReadingLogMode.pages => pagesRead,
        _ReadingLogMode.books => 1,
      };
      final streakQuantity = math.max<num>(
        1,
        widget.habit.dailyGoal == null
            ? amount
            : math.max<num>(amount, widget.habit.dailyGoal!),
      );
      final unit = switch (_mode) {
        _ReadingLogMode.time => 'min',
        _ReadingLogMode.pages => 'pages',
        _ReadingLogMode.books => 'book',
      };
      final modeName = switch (_mode) {
        _ReadingLogMode.time => 'time',
        _ReadingLogMode.pages => 'pages',
        _ReadingLogMode.books => 'books',
      };

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final userRef = firestore.collection('users').doc(uid);
      final logData = <String, dynamic>{
        'logId': logId,
        'habitId': widget.habit.id,
        'habitKind': widget.habit.kind.name,
        'logType': 'good',
        'occurredAt': Timestamp.fromDate(now),
        'loggedAt': Timestamp.fromDate(now),
        'quantity': streakQuantity,
        'readingAmount': amount,
        'streakCredit': true,
        'unit': unit,
        'readingMode': modeName,
        'type': 'reading_$modeName',
        if (_book != null) 'bookId': _book!.bookId,
        if (_book != null) 'bookTitle': _book!.title,
        if (durationMin > 0) 'durationMin': durationMin,
        if (durationMin > 0) 'durationSec': durationMin * 60,
        if (pagesRead > 0) 'pagesRead': pagesRead,
        if (rawPages > 0 && _mode == _ReadingLogMode.books)
          'finalPage': rawPages,
        if (note.isNotEmpty) 'note': note,
        'source': 'manual',
        'schemaVersion': 1,
      };

      batch.set(userRef.collection('habit_logs').doc(logId), logData);

      if (_book != null && (_mode != _ReadingLogMode.time || rawPages > 0)) {
        final nextPage = _mode == _ReadingLogMode.books
            ? rawPages
            : _book!.currentPage + pagesRead;
        batch.set(
          userRef.collection('books').doc(_book!.bookId),
          {
            'currentPage': math.max(_book!.currentPage, nextPage),
            if (_mode == _ReadingLogMode.books) 'status': 'completed',
            if (_mode == _ReadingLogMode.books)
              'completedAt': Timestamp.fromDate(now),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await ref.read(eventServiceProvider).emit(
            eventName: EventNames.goodHabitLogged,
            source: 'manual',
            payload: {
              'habitId': widget.habit.id,
              'habitName': widget.habit.name,
              'logId': logId,
              'amount': amount,
              'unit': unit,
              'readingMode': modeName,
              if (_book != null) 'bookId': _book!.bookId,
              if (durationMin > 0) 'durationMin': durationMin,
              if (pagesRead > 0) 'pagesRead': pagesRead,
              'ts': now.toIso8601String(),
              'occurredAt': now.toIso8601String(),
              'loggedAt': now.toIso8601String(),
              if (note.isNotEmpty) 'note': note,
            },
            batch: batch,
          );

      await batch.commit();
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: kCoral),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: kInk,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                color: kAmber,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 220,
      child: Center(child: CircularProgressIndicator(color: kAmber)),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;

  const _Error({required this.message});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      child: Text('Reading tracker error: $message',
          style: const TextStyle(color: kCoral)),
    );
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

class GoogleBookResult {
  final String volumeId;
  final String title;
  final String author;
  final String? coverUrl;
  final int? pageCount;
  final String? genre;
  final String? blurb;

  const GoogleBookResult({
    required this.volumeId,
    required this.title,
    required this.author,
    this.coverUrl,
    this.pageCount,
    this.genre,
    this.blurb,
  });
}

class GoogleBooksService {
  final http.Client _client;

  GoogleBooksService({http.Client? client}) : _client = client ?? http.Client();

  Future<GoogleBookResult?> lookupBook({
    required String title,
    String? author,
  }) async {
    final parts = <String>[
      'intitle:${title.trim()}',
      if (author != null && author.trim().isNotEmpty)
        'inauthor:${author.trim()}',
    ];
    final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', {
      'q': parts.join('+'),
      'maxResults': '1',
      'printType': 'books',
    });

    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleBooksException(
        'Google Books lookup failed (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    final items = decoded['items'];
    if (items is! List || items.isEmpty || items.first is! Map) return null;

    final item = Map<String, dynamic>.from(items.first as Map);
    final volume = Map<String, dynamic>.from(
      (item['volumeInfo'] as Map?) ?? const {},
    );
    final imageLinks = Map<String, dynamic>.from(
      (volume['imageLinks'] as Map?) ?? const {},
    );
    final authors = (volume['authors'] as List?)?.whereType<String>().toList();
    final categories =
        (volume['categories'] as List?)?.whereType<String>().toList();

    return GoogleBookResult(
      volumeId: item['id'] as String? ?? '',
      title: volume['title'] as String? ?? title.trim(),
      author: authors?.join(', ') ??
          (author?.trim().isNotEmpty == true ? author!.trim() : 'Unknown'),
      coverUrl: _httpsCover(
        imageLinks['thumbnail'] as String? ??
            imageLinks['smallThumbnail'] as String?,
      ),
      pageCount: (volume['pageCount'] as num?)?.toInt(),
      genre: categories?.isNotEmpty == true ? categories!.first : null,
      blurb: volume['description'] as String?,
    );
  }

  static String? _httpsCover(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.replaceFirst('http://', 'https://');
  }
}

class GoogleBooksException implements Exception {
  final String message;
  const GoogleBooksException(this.message);

  @override
  String toString() => message;
}

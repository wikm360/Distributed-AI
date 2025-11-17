import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../shared/logger.dart';
import '../shared/models.dart';

class LabsApi {
  LabsApi({http.Client? client, String? endpoint})
      : _client = client ?? http.Client(),
        _endpoint = endpoint ?? AppConfig.labsEndpoint;

  final http.Client _client;
  final String _endpoint;

  Future<List<LabCardEntry>> fetchCards() async {
    try {
      final uri = Uri.parse(_endpoint);
      final response = await _client.get(uri).timeout(AppConfig.networkTimeout);

      if (response.statusCode != 200) {
        throw LabsApiException(
          'Failed to load labs: ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> entries = switch (decoded) {
        List<dynamic> list => list,
        Map<String, dynamic> map when map['data'] is List<dynamic> =>
          List<dynamic>.from(map['data'] as List),
        _ => throw LabsApiException('Unexpected response shape'),
      };

      final cards = entries
          .map(
            (item) => switch (item) {
              Map<String, dynamic> map => LabCardEntry.fromJson(map),
              Map<dynamic, dynamic> map =>
                LabCardEntry.fromJson(map.cast<String, dynamic>()),
              _ => null,
            },
          )
          .whereType<LabCardEntry>()
          .toList();

      if (cards.isEmpty) {
        throw LabsApiException('Empty response received');
      }

      return cards;
    } catch (error, stack) {
      Log.e('Labs fetch failed: $error\n$stack', 'LabsApi');
      Log.w('Falling back to bundled Labs samples', 'LabsApi');
      return _fallbackEntries;
    }
  }

  static const List<LabCardEntry> _fallbackEntries = [
    LabCardEntry(
      id: 'sample-1',
      title: 'Beautiful weather app UI concepts we wish existed',
      description:
          'یک کارت فیک برای نمایش نمونه‌ای از لیست آزمایشگاه. می‌توانید سرور واقعی را بعداً متصل کنید.',
      author: 'Concept Lab',
      dateLabel: 'May 21, 2020',
      tags: ['Weather', 'UI', 'Inspiration', 'Public'],
    ),
    LabCardEntry(
      id: 'sample-2',
      title: '10 excellent font pairing tools for designers',
      description:
          'ایده‌های سریع برای انتخاب فونت‌های هماهنگ در پروژه‌های طراحی شما با الهام از Dribbble.',
      author: 'Studio 42',
      dateLabel: 'Feb 01, 2020',
      tags: ['Typography', 'Tools', 'Public'],
    ),
    LabCardEntry(
      id: 'sample-3',
      title: '12 eye-catching mobile UI motion patterns',
      description:
          'پترن‌های انیمیشن موبایل که تجربه کاربری را زنده می‌کنند؛ از میکروانیمیشن تا ترنزیشن‌های بین صفحات.',
      author: 'Motion Desk',
      dateLabel: 'Jun 15, 2021',
      tags: ['Motion', 'UX', 'Mobile', 'Private'],
    ),
    LabCardEntry(
      id: 'sample-4',
      title: 'How to make your personal brand stand out online',
      description:
          'چک‌لیست کوتاه برای ایجاد هویت شخصی قوی در شبکه‌های اجتماعی با تمرکز روی رنگ و تایپوگرافی.',
      author: 'BrandCraft',
      dateLabel: 'Apr 12, 2022',
      tags: ['Branding', 'Tips', 'Private'],
    ),
  ];
}

class LabsApiException implements Exception {
  LabsApiException(this.message);
  final String message;

  @override
  String toString() => 'LabsApiException: $message';
}

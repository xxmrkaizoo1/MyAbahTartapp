import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;

class LocalAiException implements Exception {
  const LocalAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to Ollama, which runs AI models on your own computer. Nothing goes to an
/// outside AI service, but the computer running Ollama has to be reachable and on.
class LocalAiService {
  LocalAiService({required String baseUrl, http.Client? client}) : baseUrl = normalizeUrl(baseUrl), _client = client ?? http.Client();

  /// Best first, chosen by trying each installed model on a sales summary.
  static const preferredModels = ['phi3:mini', 'qwen2.5-coder:1.5b', 'llama3.2:1b'];

  static const _listTimeout = Duration(seconds: 8);

  /// Small models on a laptop without a strong graphics card can take a while.
  static const _writeTimeout = Duration(minutes: 3);

  final String baseUrl;
  final http.Client _client;

  /// An Android emulator reaches the computer it runs on at 10.0.2.2. A real phone
  /// needs the computer's network address, which can be set in the app.
  static String get defaultUrl => !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:11434' : 'http://localhost:11434';

  static String normalizeUrl(String url) {
    var clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean.contains('://') ? clean : 'http://$clean';
  }

  /// Keeps the saved model while it is still installed, otherwise picks the best one.
  static String? pickModel(List<String> installed, String? saved) {
    if (installed.contains(saved)) return saved;
    for (final model in preferredModels) {
      if (installed.contains(model)) return model;
    }
    return installed.firstOrNull;
  }

  Future<List<String>> models() async {
    final data = await _send(() => _client.get(_uri('/api/tags')).timeout(_listTimeout));
    final models = data['models'];
    if (models is! List) throw const LocalAiException('Unexpected reply from the AI server.');
    return [
      for (final model in models)
        if (model is Map && model['name'] is String) model['name'] as String,
    ];
  }

  Future<String> generate({required String model, required String prompt}) async {
    final data = await _send(
      () => _client
          .post(
            _uri('/api/generate'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'prompt': prompt,
              'stream': false,
              'options': {'temperature': 0.2, 'num_predict': 220},
            }),
          )
          .timeout(_writeTimeout),
    );
    final reply = data['response'];
    if (reply is! String || reply.trim().isEmpty) throw const LocalAiException('The model gave an empty reply. Try again or choose another model.');
    return reply.trim();
  }

  void close() => _client.close();

  Uri _uri(String path) {
    final uri = Uri.tryParse('$baseUrl$path');
    if (uri == null || uri.host.isEmpty) throw LocalAiException('“$baseUrl” isn’t a valid address.');
    return uri;
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } on LocalAiException {
      rethrow;
    } catch (error) {
      throw LocalAiException('Couldn’t reach the AI server at $baseUrl. Check that Ollama is running on that computer.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw LocalAiException('$baseUrl replied, but it doesn’t look like Ollama.');
    }
    if (decoded is! Map<String, dynamic>) throw LocalAiException('$baseUrl replied, but it doesn’t look like Ollama.');
    if (response.statusCode != 200) throw LocalAiException('The AI server said: ${decoded['error'] ?? 'error ${response.statusCode}'}');
    return decoded;
  }
}

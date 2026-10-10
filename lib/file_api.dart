import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Where the Hostinger file API lives — the `hostinger/public_html/api`
/// folder of this repo, uploaded next to the web app. Event attachments and
/// uploaded profile pictures are stored there; Supabase keeps the records.
const String kFileApiBaseUrl = 'https://calendar.bongabong.gov.ph/api';

/// A refusal or failure from the file API, with its human-readable reason.
class FileApiException implements Exception {
  const FileApiException(this.message, {this.statusCode = 0});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

/// Client for the Hostinger file API. Every request carries the signed-in
/// user's Supabase access token; the API checks it with Supabase, so the
/// same permissions apply as everywhere else in the app.
class FileApi {
  FileApi({
    required String? Function() accessToken,
    http.Client? client,
    String baseUrl = kFileApiBaseUrl,
  })  : _accessToken = accessToken,
        _client = client ?? http.Client(),
        _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  final String? Function() _accessToken;
  final http.Client _client;
  final String _baseUrl;

  Map<String, String> _authHeaders() {
    final token = _accessToken();
    if (token == null || token.isEmpty) {
      throw const FileApiException('Sign in first.', statusCode: 401);
    }
    // Sent twice: some hosting setups strip Authorization before PHP sees
    // it, and the API also accepts X-Auth-Token for that reason.
    return {'Authorization': 'Bearer $token', 'X-Auth-Token': token};
  }

  Uri _uri(String script, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl/$script').replace(queryParameters: query);

  Future<http.Response> _send(http.BaseRequest request) async {
    final streamed = await _client.send(request).timeout(const Duration(seconds: 60));
    return http.Response.fromStream(streamed);
  }

  Never _fail(http.Response response) {
    var message = 'The file server answered ${response.statusCode}.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is String) message = decoded['error'] as String;
    } catch (_) {}
    throw FileApiException(message, statusCode: response.statusCode);
  }

  Map<String, dynamic> _json(http.Response response, {int expected = 200}) {
    if (response.statusCode != expected) _fail(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Uploads an attachment to [eventId] (poster only); returns its new
  /// `event_attachments` row.
  Future<Map<String, dynamic>> uploadAttachment(
    String eventId,
    String fileName,
    Uint8List bytes, {
    String? mimeType,
  }) async {
    final request = http.MultipartRequest('POST', _uri('attachments.php'))
      ..headers.addAll(_authHeaders())
      ..fields['event_id'] = eventId
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    return _json(await _send(request), expected: 201);
  }

  /// The attachment's bytes (for showing a picture inside the app).
  Future<Uint8List> downloadAttachment(String attachmentId) async {
    final response = await _client
        .get(_uri('attachments.php', {'id': attachmentId}), headers: _authHeaders())
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) _fail(response);
    return response.bodyBytes;
  }

  /// A link to the attachment that works for an hour without signing in —
  /// for opening a document in another app or the browser.
  Future<String> attachmentLink(String attachmentId) async {
    final response = await _client
        .get(_uri('attachments.php', {'action': 'link', 'id': attachmentId}), headers: _authHeaders())
        .timeout(const Duration(seconds: 30));
    return _json(response)['url'] as String;
  }

  /// Removes an attachment (poster only) — its record and its file.
  Future<void> deleteAttachment(String attachmentId) async {
    final response = await _client
        .delete(_uri('attachments.php', {'id': attachmentId}), headers: _authHeaders())
        .timeout(const Duration(seconds: 30));
    _json(response);
  }

  /// Uploads the user's own profile photo (already cropped/resized by the
  /// app; the server re-encodes it too) and sets it as their picture.
  /// Returns the photo's public link.
  Future<String> uploadProfilePhoto(Uint8List jpegBytes) async {
    final request = http.MultipartRequest('POST', _uri('avatars.php'))
      ..headers.addAll(_authHeaders())
      ..files.add(http.MultipartFile.fromBytes('file', jpegBytes, filename: 'photo.jpg'));
    return _json(await _send(request), expected: 201)['url'] as String;
  }

  /// Deletes the user's uploaded photo files (after they switch back to a
  /// preset picture). Best effort — a leftover file is harmless.
  Future<void> deleteOwnPhoto() async {
    final response = await _client.delete(_uri('avatars.php'), headers: _authHeaders()).timeout(const Duration(seconds: 30));
    _json(response);
  }
}

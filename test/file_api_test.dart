import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

import 'package:eCalendar/event_store.dart';
import 'package:eCalendar/file_api.dart';
import 'package:eCalendar/image_prep.dart';

/// A big PNG with photo-like (noisy) pixels — a smooth gradient would
/// compress better as PNG than JPEG, unlike a real photo.
Uint8List bigPhoto() {
  final random = Random(7);
  final image = img.Image(width: 3000, height: 2000);
  for (var y = 0; y < image.height; y += 1) {
    for (var x = 0; x < image.width; x += 1) {
      image.setPixelRgb(x, y, random.nextInt(256), random.nextInt(256), random.nextInt(256));
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('image prep', () {
    test('a large photo is shrunk to at most 1600px and re-encoded as JPEG', () async {
      final original = bigPhoto();
      final result = await shrinkImageForUpload(original);
      expect(result.reencoded, isTrue);
      expect(result.bytes.length, lessThan(original.length));
      final decoded = img.decodeJpg(result.bytes)!;
      expect(decoded.width, 1600);
      expect(decoded.height, 1067);
    });

    test('something that isn\'t a picture is left untouched', () async {
      final notAPicture = Uint8List.fromList(utf8.encode('%PDF-1.4 hello'));
      final result = await shrinkImageForUpload(notAPicture);
      expect(result.reencoded, isFalse);
      expect(result.bytes, notAPicture);
    });

    test('a profile photo is cropped square to 512px', () async {
      final photo = await squareProfilePhoto(bigPhoto());
      final decoded = img.decodeJpg(photo)!;
      expect(decoded.width, 512);
      expect(decoded.height, 512);
    });

    test('a profile photo that isn\'t a picture is refused', () async {
      expect(() => squareProfilePhoto(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    });
  });

  group('FileApi', () {
    test('sends the login token both ways and returns the new attachment row', () async {
      late http.BaseRequest seen;
      final api = FileApi(
        accessToken: () => 'tok-123',
        baseUrl: 'https://files.example/api/',
        client: MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'id': 'a1', 'storage_provider': 'hostinger'}), 201);
        }),
      );
      final row = await api.uploadAttachment('ev1', 'agenda.pdf', Uint8List.fromList([1, 2, 3]));
      expect(row['storage_provider'], 'hostinger');
      expect(seen.url.toString(), 'https://files.example/api/attachments.php');
      expect(seen.headers['Authorization'], 'Bearer tok-123');
      expect(seen.headers['X-Auth-Token'], 'tok-123');
    });

    test('shows the server\'s own reason when it refuses', () async {
      final api = FileApi(
        accessToken: () => 'tok',
        client: MockClient((_) async => http.Response(jsonEncode({'error': 'An event can have up to 5 files.'}), 409)),
      );
      expect(
        () => api.uploadAttachment('ev1', 'x.png', Uint8List(1)),
        throwsA(isA<FileApiException>()
            .having((e) => e.message, 'message', 'An event can have up to 5 files.')
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('refuses to call the server when nobody is signed in', () async {
      var called = false;
      final api = FileApi(
        accessToken: () => null,
        client: MockClient((_) async {
          called = true;
          return http.Response('', 200);
        }),
      );
      await expectLater(() => api.attachmentLink('a1'), throwsA(isA<FileApiException>()));
      expect(called, isFalse);
    });

    test('profile photo upload returns the picture link', () async {
      final api = FileApi(
        accessToken: () => 'tok',
        client: MockClient((request) async {
          expect(request.url.path, endsWith('/avatars.php'));
          return http.Response(jsonEncode({'url': 'https://site/media/avatars/users/u-1.jpg'}), 201);
        }),
      );
      expect(await api.uploadProfilePhoto(Uint8List(4)), 'https://site/media/avatars/users/u-1.jpg');
    });
  });

  test('attachments remember where they are stored', () {
    final newer = EventAttachment.fromSupabase({
      'id': 'a1',
      'event_id': 'ev1',
      'storage_path': 'ev1/x.png',
      'file_name': 'x.png',
      'storage_provider': 'hostinger',
    });
    final older = EventAttachment.fromSupabase({
      'id': 'a2',
      'event_id': 'ev1',
      'storage_path': 'ev1/y.png',
      'file_name': 'y.png',
    });
    expect(newer.isOnHostinger, isTrue);
    expect(older.isOnHostinger, isFalse);
  });
}

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// Shrinks a picture before it's uploaded, so attachments stay small on the
/// file server: turned upright, scaled down to at most [maxSide] pixels on
/// its longest side, and saved as a JPEG. A phone photo of several MB
/// usually ends up around 150–300 KB with no visible difference on screen.
///
/// Returns the original bytes (`reencoded: false`) when they can't be decoded
/// (e.g. a format the image library doesn't know) or when shrinking
/// wouldn't make them smaller. Runs off the UI thread on phones and
/// desktop.
Future<({Uint8List bytes, bool reencoded})> shrinkImageForUpload(
  Uint8List bytes, {
  int maxSide = 1600,
  int quality = 80,
}) {
  return compute(_shrink, (bytes: bytes, maxSide: maxSide, quality: quality));
}

({Uint8List bytes, bool reencoded}) _shrink(({Uint8List bytes, int maxSide, int quality}) args) {
  final decoded = _tryDecode(args.bytes);
  if (decoded == null) return (bytes: args.bytes, reencoded: false);
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > args.maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: args.maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: args.maxSide, interpolation: img.Interpolation.average);
  }
  final jpeg = Uint8List.fromList(img.encodeJpg(image, quality: args.quality));
  return jpeg.length < args.bytes.length
      ? (bytes: jpeg, reencoded: true)
      : (bytes: args.bytes, reencoded: false);
}

/// A profile photo: center-cropped to a square, upright, [size] pixels,
/// JPEG. Throws a [FormatException] when the bytes aren't a picture.
Future<Uint8List> squareProfilePhoto(Uint8List bytes, {int size = 512}) {
  return compute(_square, (bytes: bytes, size: size));
}

Uint8List _square(({Uint8List bytes, int size}) args) {
  final decoded = _tryDecode(args.bytes);
  if (decoded == null) throw const FormatException('Not a picture');
  final image = img.bakeOrientation(decoded);
  final side = image.width < image.height ? image.width : image.height;
  final cropped = img.copyCrop(
    image,
    x: (image.width - side) ~/ 2,
    y: (image.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final resized = side > args.size
      ? img.copyResize(cropped, width: args.size, height: args.size, interpolation: img.Interpolation.average)
      : cropped;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}

/// The decoded picture, or null — the image library can throw (not just
/// return null) on data that merely looks like a picture format.
img.Image? _tryDecode(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
}

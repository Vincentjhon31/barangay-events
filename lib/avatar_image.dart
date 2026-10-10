import 'package:flutter/material.dart';

/// A profile picture is either a built-in picture (an `assets/avatars/...`
/// path) or a picture on the Hostinger file server (a superadmin preset or
/// the user's own photo — an `https://` link). These helpers draw either.

/// Whether [path] is a web link rather than a built-in picture.
bool isWebPicture(String? path) =>
    path != null && (path.startsWith('https://') || path.startsWith('http://'));

ImageProvider avatarImageProvider(String path) =>
    isWebPicture(path) ? NetworkImage(path) : AssetImage(path) as ImageProvider;

/// The picture at [path], or [fallback] if it can't be shown (missing
/// asset, no connection, deleted file).
Widget avatarImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? fallback,
}) {
  Widget onError(BuildContext context, Object error, StackTrace? stack) =>
      fallback ?? SizedBox(width: width, height: height);
  if (isWebPicture(path)) {
    return Image.network(
      path,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: onError,
    );
  }
  return Image.asset(path, width: width, height: height, fit: fit, errorBuilder: onError);
}

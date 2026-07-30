import 'package:flutter/material.dart';

/// The fixed palette a user picks an event's color label from (like Google
/// Calendar) — stored on `BarangayEvent.colorKey` as one of these keys, not
/// a raw hex value, so the actual colors live in exactly one place and can
/// be retuned later without touching any stored data. Deliberately
/// distinct from the app's existing fixed accent colors (`#2B7FFF` for
/// Public, `#1F9D65` for Group, etc. — see main.dart's `_eventTypeTint`)
/// so a chosen color label never gets confused with the event-type badge.
const Map<String, Color> eventColorPalette = {
  'tomato': Color(0xFFE85D50),
  'tangerine': Color(0xFFF0932B),
  'banana': Color(0xFFF2C94C),
  'basil': Color(0xFF2FA36B),
  'peacock': Color(0xFF2B8FD6),
  'blueberry': Color(0xFF5B6ACF),
  'grape': Color(0xFF9B59B6),
  'graphite': Color(0xFF7A8288),
};

/// Human-readable label for a palette key, for the picker UI and any
/// accessibility text — not localized, since these are proper-noun-style
/// color names.
const Map<String, String> eventColorNames = {
  'tomato': 'Tomato',
  'tangerine': 'Tangerine',
  'banana': 'Banana',
  'basil': 'Basil',
  'peacock': 'Peacock',
  'blueberry': 'Blueberry',
  'grape': 'Grape',
  'graphite': 'Graphite',
};

/// Resolves a stored `colorKey` to its `Color`, or `null` if [key] is null
/// or unrecognized (e.g. an older/newer client using a key this build
/// doesn't know) — callers should fall back to the existing keyword-based
/// tint in that case, exactly as for an event with no color chosen at all.
Color? colorForKey(String? key) => key == null ? null : eventColorPalette[key];

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'roster.dart';

/// FACES ON THE NOTIFICATIONS.
///
/// The copy was already right — the midday slot is a message from a woman
/// in his Rolodex, by name, and the evening is Lucien. What it was
/// missing is the thing that makes a notification a *message* instead of
/// an announcement: a face. A push with an avatar reads as a person; the
/// same words with no image read as the app talking about itself, and men
/// have been trained for a decade to swipe those away unread.
///
/// WHY THE IMAGES HAVE TO BE COPIED TO DISK FIRST.
/// flutter_local_notifications cannot take a Flutter asset path. Both
/// platforms need a real file the OS can open:
///   * iOS  — DarwinNotificationAttachment(filePath). Copied into the
///            notification when it is SCHEDULED, so the file only has to
///            exist at schedule time.
///   * Android — FilePathAndroidBitmap(path), read at DISPLAY time, which
///            can be up to 14 days after scheduling. That is why these
///            live in Application Support (persistent) and not in the
///            cache directory, which the OS is free to purge — a purge
///            would silently strip the faces off every pending push.
///
/// The source art is a 0.7-ratio portrait with the face in the upper
/// two-thirds, so a square crop from the TOP is the face; a centre crop
/// would cut her chin off. Decoded straight to 256px because the target
/// is a small avatar — handing the notification system a 700px PNG to
/// scale down on every display is work for no pixels.
abstract final class NotificationMedia {
  /// Bump to force a re-render after changing the art or the crop.
  static const _version = 1;
  static const _kVersionKey = 'notif_media.version';

  /// Output edge in px. An Android large icon renders around 64dp and an
  /// iOS attachment thumbnail smaller still; 256 covers 3x screens with
  /// room to spare and keeps each file well under 100KB.
  static const _edge = 256;

  static final Map<String, String> _paths = {};
  /// Single-flight guard. reschedule() is called fire-and-forget from
  /// several places, so two primes can overlap on a cold start — and a
  /// plain bool set on entry would also mean a transient failure
  /// permanently disables faces for the whole session. Holding the
  /// Future gives both callers the same work and lets a failed run be
  /// retried by the next one.
  static Future<void>? _inflight;

  /// Resolved file path for a roster asset, or null if it hasn't been
  /// rendered. Callers must treat null as "send the push without a
  /// face" — a missing image is never a reason to drop a notification.
  static String? pathForAsset(String assetPath) => _paths[assetPath];

  /// Face for a girl id (`amara`, `ice_queen`, …), or null.
  static String? pathForGirl(String girlId) =>
      pathForAsset(girlById(girlId).asset);

  static const lucienAsset = 'assets/characters/lucien/lucien.png';

  /// Lucien's face for the evening coach slot, or null.
  static String? get lucienPath => pathForAsset(lucienAsset);

  /// Render every face to disk. Call once at launch BEFORE the nudge
  /// horizon is scheduled, since scheduling is what bakes the iOS
  /// attachments in. Cheap after the first run: it re-reads the paths
  /// off disk and decodes nothing.
  /// [_prime] swallows its own errors, so the shared Future never
  /// completes with one.
  static Future<void> prime() => _inflight ??= _prime();

  static Future<void> _prime() async {
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}'
          '/notif_faces');
      if (!await dir.exists()) await dir.create(recursive: true);

      final prefs = await SharedPreferences.getInstance();
      final fresh = prefs.getInt(_kVersionKey) == _version;

      final assets = <String>{
        for (final g in kRoster) g.asset,
        lucienAsset,
      };

      for (final asset in assets) {
        final out = File('${dir.path}/${_slug(asset)}.png');
        if (fresh && await out.exists()) {
          _paths[asset] = out.path;
          continue;
        }
        final bytes = await _renderSquare(asset);
        if (bytes == null) continue;
        await out.writeAsBytes(bytes, flush: true);
        _paths[asset] = out.path;
      }
      await prefs.setInt(_kVersionKey, _version);
    } catch (e) {
      // Never fatal. Without faces the pushes still go out with their
      // copy intact, which is the behaviour we had before this existed.
      // Clearing the guard lets the next reschedule try again — a full
      // disk or a mid-render kill shouldn't cost faces until relaunch.
      _inflight = null;
      debugPrint('NotificationMedia.prime failed: $e');
    }
  }

  /// Decode at avatar size → square-crop to the face → re-encode PNG.
  static Future<Uint8List?> _renderSquare(String asset) async {
    ui.Image? src;
    ui.Image? cropped;
    try {
      final data = await rootBundle.load(asset);
      // Downscale during decode rather than after: the full-size frame
      // is never allocated.
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        targetWidth: _edge,
      );
      final frame = await codec.getNextFrame();
      // Bound to a FINAL local and used through that, rather than
      // through the nullable `src`. Reading `src.width` relies on
      // assignment promotion, and promotion on a mutable local is
      // exactly the thing that has failed an archive in this repo
      // before. `src` still holds it purely so `finally` can dispose it.
      final image = frame.image;
      src = image;

      final side = math.min(image.width, image.height).toDouble();
      // WHERE THE SQUARE SITS ON A 0.7-RATIO PORTRAIT.
      //
      // Top-anchored (0.0) was the obvious choice and it was wrong — it
      // cut mouths and chins off half the roster, because the art frames
      // the face slightly below the top edge. A plain centre crop (0.5)
      // pushes chins onto the bottom edge instead. 0.35 down the slack
      // puts every one of the ten faces complete and centred, checked
      // against the actual art.
      //
      // It is checked as a CIRCLE, not a square: Android 12+ clips a
      // notification large icon to a circle, so the corners are not
      // real estate and anything near an edge is gone.
      const anchor = 0.35;
      final srcRect = ui.Rect.fromLTWH(
        (image.width - side) / 2,
        (image.height - side) * anchor,
        side,
        side,
      );

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        image,
        srcRect,
        ui.Rect.fromLTWH(0, 0, _edge.toDouble(), _edge.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final square = await recorder.endRecording().toImage(_edge, _edge);
      cropped = square;

      final png = await square.toByteData(format: ui.ImageByteFormat.png);
      return png?.buffer.asUint8List();
    } catch (e) {
      debugPrint('NotificationMedia render failed for $asset: $e');
      return null;
    } finally {
      src?.dispose();
      cropped?.dispose();
    }
  }

  static String _slug(String assetPath) =>
      assetPath.split('/').last.replaceAll('.png', '');
}

/// Android notification channel IDs — one place, because a channel ID is
/// permanent user-facing state.
///
/// Once a channel exists on a device, Android owns it: the user's sound,
/// importance and on/off choice live against that ID and CANNOT be
/// changed by the app. Two consequences that this file exists to keep
/// straight:
///
///   * Renaming an ID does not rename a channel, it creates a second one.
///     The old one stays in Settings forever as a dead entry, and any
///     user who had muted it silently gets un-muted under the new ID.
///     [NotificationService.init] deletes the retired IDs explicitly.
///   * Splitting one channel into several is a one-way door, so the split
///     should follow what a user would actually want to control
///     separately — not our internal code structure.
///
/// The split here is deliberate. A man will happily mute "Daily
/// motivation" and keep "Messages": one is an app nagging him, the other
/// is a woman he's been talking to. Putting both on one channel means the
/// first one he resents costs us the second.
abstract final class NotifChannels {
  /// Morning identity / dream push.
  static const dream = 'daily_dream';

  /// Evening streak + loss nudge (Lucien).
  static const streak = 'daily_streak';

  /// A woman from his Rolodex, by name and face. Kept separate so it
  /// survives him muting the marketing.
  static const her = 'imhim.her';

  /// Protocol streak reminders (legacy Mirrorly protocol feature).
  static const protocolStreak = 'imhim.streak';

  /// Rescan milestone reminders.
  static const rescan = 'imhim.rescan';

  /// Training-streak nudge (Eyes + Game tabs).
  static const training = 'imhim.training';

  /// Retired IDs, deleted on init so they don't sit in the user's
  /// notification settings as dead entries. Never reuse one of these:
  /// a device that still remembers the old channel would resurrect the
  /// old settings with it.
  static const retired = <String>[
    'mirrorly.streak',
    'mirrorly.rescan',
    'mirrorly.training',
  ];
}

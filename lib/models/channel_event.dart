/// A channel event worth surfacing as an alert (sub, raid, etc.).
///
/// Sourced from Twitch IRC USERNOTICE lines; donations/cheers arrive later
/// via Helix EventSub. Kept deliberately small — the agent API just relays it.
class ChannelEvent {
  /// Event type: 'subscription', 'resub', 'raid', 'follow' (reserved).
  final String type;

  /// Display name of the user who triggered the event.
  final String user;

  /// Months for resubs, viewer count for raids, otherwise null.
  final int? count;

  /// Personal message attached to a resub, if any.
  final String? message;

  final String time;

  ChannelEvent({
    required this.type,
    required this.user,
    this.count,
    this.message,
    required this.time,
  });

  factory ChannelEvent.fromJson(Map<String, dynamic> json) {
    return ChannelEvent(
      type: json['type'] as String? ?? '',
      user: json['user'] as String? ?? '?',
      count: json['count'] as int?,
      message: json['message'] as String?,
      time: json['time'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'user': user,
        if (count != null) 'count': count,
        if (message != null) 'message': message,
        'time': time,
      };
}

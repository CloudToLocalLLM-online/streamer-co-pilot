/// A single chat message from any streaming platform.
class ChatMessage {
  final String time;
  final String user;
  final String text;
  final bool isMod;
  final bool isSub;
  final bool isVip;
  final bool isBroadcaster;
  final String id;

  ChatMessage({
    required this.time,
    required this.user,
    required this.text,
    this.isMod = false,
    this.isSub = false,
    this.isVip = false,
    this.isBroadcaster = false,
    this.id = '',
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      time: json['time'] as String? ?? '',
      user: json['user'] as String? ?? '?',
      text: json['text'] as String? ?? '',
      isMod: json['is_mod'] == true,
      isSub: json['is_sub'] == true,
      isVip: json['is_vip'] == true,
      isBroadcaster: json['is_broadcaster'] == true,
      id: json['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'user': user,
        'text': text,
        'is_mod': isMod,
        'is_sub': isSub,
        'is_vip': isVip,
        'is_broadcaster': isBroadcaster,
        'id': id,
      };
}
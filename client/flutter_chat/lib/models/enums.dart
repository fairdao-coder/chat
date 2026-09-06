/// Chat scope. Serialized as "Private" / "Group" to match the server
/// (server uses [JsonConverter(JsonStringEnumConverter)]).
enum ChatType { private, group }

/// Message kind. Serialized as "Text" / "Image" / "File" / "Voice" to match the server.
enum MessageType { text, image, file, voice }

ChatType chatTypeFromJson(String? v) {
  switch (v) {
    case 'Group':
      return ChatType.group;
    case 'Private':
    default:
      return ChatType.private;
  }
}

String chatTypeToJson(ChatType t) => t == ChatType.group ? 'Group' : 'Private';

MessageType messageTypeFromJson(String? v) {
  switch (v) {
    case 'Image':
      return MessageType.image;
    case 'File':
      return MessageType.file;
    case 'Voice':
      return MessageType.voice;
    case 'Text':
    default:
      return MessageType.text;
  }
}

String messageTypeToJson(MessageType t) {
  switch (t) {
    case MessageType.image:
      return 'Image';
    case MessageType.file:
      return 'File';
    case MessageType.voice:
      return 'Voice';
    case MessageType.text:
      return 'Text';
  }
}

/// Matches server CallType (JsonStringEnumConverter serializes as "Voice" / "Video").
enum CallType { voice, video }

CallType callTypeFromJson(String? v) {
  switch (v) {
    case 'Video':
      return CallType.video;
    case 'Voice':
    default:
      return CallType.voice;
  }
}

String callTypeToJson(CallType t) => t == CallType.video ? 'Video' : 'Voice';

/// Matches server CallState.
enum CallState { calling, connecting, connected, ended }

CallState callStateFromJson(String? v) {
  switch (v) {
    case 'Connecting':
      return CallState.connecting;
    case 'Connected':
      return CallState.connected;
    case 'Ended':
      return CallState.ended;
    case 'Calling':
    default:
      return CallState.calling;
  }
}

/// Matches server CallEndReason.
enum CallEndReason { declined, busy, timeout, hangUp, offline, error }

CallEndReason callEndReasonFromJson(String? v) {
  switch (v) {
    case 'Declined':
      return CallEndReason.declined;
    case 'Busy':
      return CallEndReason.busy;
    case 'Timeout':
      return CallEndReason.timeout;
    case 'HangUp':
      return CallEndReason.hangUp;
    case 'Offline':
      return CallEndReason.offline;
    case 'Error':
    default:
      return CallEndReason.error;
  }
}

String callEndReasonKey(CallEndReason r) {
  switch (r) {
    case CallEndReason.declined:
      return '对方已拒绝';
    case CallEndReason.busy:
      return '对方忙线';
    case CallEndReason.timeout:
      return '对方无应答';
    case CallEndReason.hangUp:
      return '通话结束';
    case CallEndReason.offline:
      return '对方不在线';
    case CallEndReason.error:
      return '连接失败';
  }
}

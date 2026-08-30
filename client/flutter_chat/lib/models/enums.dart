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

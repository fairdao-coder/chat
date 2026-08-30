import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/signalr_client.dart';

/// Single instance of the REST client.
final apiProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

/// Single instance of the SignalR hub wrapper.
final hubProvider = Provider<ChatHubClient>((ref) {
  return ChatHubClient();
});

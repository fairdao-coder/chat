import '../config/app_config.dart';

/// Resolve a possibly-relative media URL (e.g. "/files/xxx.png") into an
/// absolute URL using the configured API base.
String resolveUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${AppConfig.apiBase}${url.startsWith('/') ? '' : '/'}$url';
}

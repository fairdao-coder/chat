class FileUploadResult {
  final String url;
  final String contentType;
  final int size;

  const FileUploadResult({
    required this.url,
    required this.contentType,
    required this.size,
  });

  factory FileUploadResult.fromJson(Map<String, dynamic> j) => FileUploadResult(
        url: j['url'] as String,
        contentType: (j['contentType'] as String?) ?? '',
        size: (j['size'] as int?) ?? 0,
      );
}

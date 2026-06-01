class StoragePathUtil {
  static String? fromUrl(String url, String bucket) {
    final marker = '/object/public/$bucket/';
    final idx = url.indexOf(marker);
    if (idx == -1) return null;
    return url.substring(idx + marker.length);
  }
}

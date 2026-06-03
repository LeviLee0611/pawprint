/// Supabase Storage URL을 Transform API URL로 변환
/// /storage/v1/object/public/ → /storage/v1/render/image/public/
/// 변환 실패 시 원본 URL 반환 (안전)
String toTransformUrl(String? url, {int? width, int? height, int? quality, String? resize}) {
  if (url == null || url.isEmpty) return '';
  const objectPath = '/storage/v1/object/public/';
  const renderPath = '/storage/v1/render/image/public/';
  if (!url.contains(objectPath)) return url;

  final base = url.replaceFirst(objectPath, renderPath);
  final params = <String>[];
  if (width != null) params.add('width=$width');
  if (height != null) params.add('height=$height');
  if (quality != null) params.add('quality=$quality');
  if (resize != null) params.add('resize=$resize');
  return params.isEmpty ? base : '$base?${params.join('&')}';
}

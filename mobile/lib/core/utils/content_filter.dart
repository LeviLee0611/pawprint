// 서버 사이드 검사 전 1차 클라이언트 필터
// 목적: 명백한 불법 광고·스팸을 빠르게 거부, 이미지 업로드 낭비 방지
class ContentFilter {
  static const _blocked = [
    // 불법 도박
    '카지노', '바카라', '홀덤', '불법도박', '불법배팅', '배팅사이트',
    // 불법 금융
    '불법대출', '급전대출', '무직자대출', '신용불량대출', '사채업자',
    // 마약
    '필로폰', '대마초', '마약팔', '떨팔', '아이스팔',
    // 성인 광고
    '조건만남', '원나잇', '성인방', '야동',
    // 스팸 단축 URL
    'bit.ly', 'tinyurl.com', 'goo.gl',
  ];

  /// null 반환 = 통과, String 반환 = 거부 사유
  static String? check(String text) {
    final t = text.toLowerCase().replaceAll(' ', '');
    for (final word in _blocked) {
      if (t.contains(word)) return '부적절한 내용이 포함돼 있어요';
    }
    return null;
  }
}

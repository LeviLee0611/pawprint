export function formatRelativeTime(isoString: string): string {
  const now = Date.now()
  const date = new Date(isoString).getTime()
  const diff = now - date

  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(diff / 3600000)
  const days = Math.floor(diff / 86400000)

  if (minutes < 1) return '방금 전'
  if (minutes < 60) return `${minutes}분 전`
  if (hours < 24) return `${hours}시간 전`
  if (days < 7) return `${days}일 전`

  return new Date(isoString).toLocaleDateString('ko-KR')
}

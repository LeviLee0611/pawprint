import Image from 'next/image'

interface AvatarProps {
  src?: string | null
  name: string
  size?: 'sm' | 'md' | 'lg'
}

const sizeStyles = {
  sm: 'h-7 w-7 text-xs',
  md: 'h-9 w-9 text-sm',
  lg: 'h-12 w-12 text-base',
}

const sizePx = { sm: 28, md: 36, lg: 48 }

export function Avatar({ src, name, size = 'md' }: AvatarProps) {
  const initials = name.charAt(0).toUpperCase()

  if (src) {
    return (
      <div className={`relative rounded-full overflow-hidden shrink-0 ${sizeStyles[size]}`}>
        <Image src={src} alt={name} width={sizePx[size]} height={sizePx[size]} className="object-cover" />
      </div>
    )
  }

  return (
    <div className={`rounded-full bg-orange-100 text-orange-600 font-semibold flex items-center justify-center shrink-0 ${sizeStyles[size]}`}>
      {initials}
    </div>
  )
}

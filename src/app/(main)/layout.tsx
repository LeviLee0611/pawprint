import { Header } from '@/components/layout/Header'

export default function MainLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <Header />
      <main className="max-w-2xl mx-auto px-4 py-6">{children}</main>
    </>
  )
}

import { useState, useEffect } from 'react'
import Navbar from './components/Navbar'
import Hero from './components/Hero'
import Features from './components/Features'
import Screenshots from './components/Screenshots'
import DownloadSection from './components/Download'
import Community from './components/Community'
import Footer from './components/Footer'
import PrivacyPolicy from './components/PrivacyPolicy'
import AnimatedBackground from './components/effects/AnimatedBackground'
import './App.css'

function App() {
  const [showPrivacy, setShowPrivacy] = useState(false)

  // Check URL path on mount for direct /privacy access
  useEffect(() => {
    if (window.location.pathname === '/privacy') {
      setShowPrivacy(true)
    }
  }, [])

  const handlePrivacyClick = (e) => {
    if (e) e.preventDefault()
    setShowPrivacy(true)
    window.history.pushState(null, '', '/privacy')
  }

  const handleBackToHome = () => {
    setShowPrivacy(false)
    window.history.pushState(null, '', '/')
  }

  if (showPrivacy) {
    return (
      <div className="app">
        <AnimatedBackground />
        <PrivacyPolicy onBack={handleBackToHome} />
      </div>
    )
  }

  return (
    <div className="app">
      <AnimatedBackground />
      <Navbar onPrivacyClick={handlePrivacyClick} />
      <main>
        <Hero />
        <Features />
        <Screenshots />
        <DownloadSection />
        <Community />
      </main>
      <Footer onPrivacyClick={handlePrivacyClick} />
    </div>
  )
}

export default App

import { useEffect, useRef } from 'react'

/**
 * Component that listens for messages from the service worker
 * to play notification sounds when push notifications are received
 */
export function NotificationSoundPlayer() {
  const audioRef = useRef<HTMLAudioElement | null>(null)

  useEffect(() => {
    // Create audio element for notification sound
    const audio = new Audio('/sounds/call-peer-join.mp3')

    audio.volume = 0.5

    audioRef.current = audio

    // Simple message handler - just try to play the sound
    const handleMessage = (event: MessageEvent) => {
      if (event.data?.type === 'PLAY_NOTIFICATION_SOUND' && audioRef.current) {
        // Create a fresh audio element each time to avoid state issues
        const sound = new Audio('/sounds/call-peer-join.mp3')

        sound.volume = 0.5
        
        sound.play().catch((error) => {
          // eslint-disable-next-line no-console
          console.error('Failed to play notification sound:', error)
        })
      }
    }

    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.addEventListener('message', handleMessage)
    }

    return () => {
      if ('serviceWorker' in navigator) {
        navigator.serviceWorker.removeEventListener('message', handleMessage)
      }
    }
  }, [])

  return null // This component doesn't render anything
}

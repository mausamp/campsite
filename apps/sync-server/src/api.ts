import { Api } from '@campsite/types'

let baseUrl = 'http://api.campsite.test:3001'

if (process.env.NODE_ENV === 'production') {
  const prodBaseUrl = process.env.API_BASE_URL

  if (!prodBaseUrl) {
    throw new Error('API_BASE_URL must be set in production')
  }

  baseUrl = prodBaseUrl
}

export const api = new Api({
  baseUrl,
  baseApiParams: {
    headers: { 'Content-Type': 'application/json' },
    format: 'json'
  }
})

# frozen_string_literal: true

require "nanoid"

module MediaUrlBuilder
  extend ActiveSupport::Concern

  FALLBACK_AVATAR_COLORS = [
    "3b82f6", # blue.500
    "4ade80", # green.400
    "fde047", # yellow.300
    "ef4444", # red.500
    "9333ea", # purple.300
    "ec4899", # pink.500
    "6366f1", # indigo.500
    "5eead4", # teal.300
  ].freeze

  # === Helpers ===

  def fallback_avatar(name = "", append_params = {})
    color = FALLBACK_AVATAR_COLORS[name.each_byte.sum % FALLBACK_AVATAR_COLORS.length]
    build_imgix_url(
      "static/avatars/#{name[0] ? name[0].upcase : "blank"}.png",
      append_params.merge("blend-color": color)
    )
  end

  # Build URL for files served through your Cloudflare CDN domain
  def build_imgix_url(path, append_params = {})
    uri = Addressable::URI.parse(Rails.application.credentials.dig(:cloudflare, :cdn_url))
    # example: https://cdn.example.com
    uri.path = "/cdn/#{path}" # or just `path` if you're proxying bucket directly

    if append_params.present?
      uri.query_values = append_params.compact.merge(uri.query_values || {})
    end

    uri.to_s
  end

  # If you have multiple zones or special buckets (like imgix_folder before)
  def build_imgix_folder_url(path, append_params = {})
    folder_cdn_url = Rails.application.credentials.dig(:cloudflare, :folder_cdn_url)
    # Fallback to main cdn_url if folder_cdn_url is not configured
    folder_cdn_url ||= Rails.application.credentials.dig(:cloudflare, :cdn_url)
    
    uri = Addressable::URI.parse(folder_cdn_url)
    uri.path = "/cdn/#{path}"
    if append_params.present?
      uri.query_values = append_params.compact.merge(uri.query_values || {})
    end
    uri.to_s
  end

  def build_imgix_video_url(path, append_params = {})
    video_cdn_url = Rails.application.credentials.dig(:cloudflare, :video_cdn_url)
    # Fallback to main cdn_url if video_cdn_url is not configured
    video_cdn_url ||= Rails.application.credentials.dig(:cloudflare, :cdn_url)
    
    uri = Addressable::URI.parse(video_cdn_url)
    uri.path = "/cdn/#{path}"
    if append_params.present?
      uri.query_values = append_params.compact.merge(uri.query_values || {})
    end
    uri.to_s
  end
end

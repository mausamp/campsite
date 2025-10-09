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

  # Returns the provider key as a lowercase string. Possible values: 'cloudflare', 'imgix', etc.
  def media_provider_key
    @media_provider_key ||= Rails.application.credentials.dig(:media, :provider)&.to_s || 'cloudflare'
  end

  # Standardized method to build media URLs based on configured provider
  def build_url(path, params = {})
    return nil if path.blank?

    case media_provider_key.downcase
    when 'imgix'
      build_imgix_provider_url(path, params)
    when 'cloudflare', 'cloudflare_cdn'
      build_cloudflare_provider_url(path, params)
    else
      build_cloudflare_provider_url(path, params)
    end
  end

  def build_folder_url(path, params = {})
    case media_provider_key.downcase
    when 'imgix'
      build_imgix_provider_folder_url(path, params)
    else
      build_url(path, params)
    end
  end

  def build_video_url(path, params = {})
    case media_provider_key.downcase
    when 'imgix'
      build_imgix_provider_video_url(path, params)
    else
      build_url(path, params)
    end
  end

  def fallback_avatar(name = '', params = {})
    color = FALLBACK_AVATAR_COLORS[name.each_byte.sum % FALLBACK_AVATAR_COLORS.length]
    build_url("static/avatars/#{name[0] ? name[0].upcase : "blank"}.png", params.merge("blend-color": color))
  end

  # Backwards-compatible aliases for the legacy method names many models already call.
  def build_imgix_url(path, params = {})
    build_url(path, params)
  end

  def build_imgix_folder_url(path, params = {})
    build_folder_url(path, params)
  end

  def build_imgix_video_url(path, params = {})
    build_video_url(path, params)
  end

  # Cloudflare CDN aliases
  alias_method :build_cloudflare_cdn_url, :build_url
  alias_method :build_cloudflare_folder_url, :build_folder_url
  alias_method :build_cloudflare_video_url, :build_video_url

  private

  # Imgix provider implementation
  def build_imgix_provider_url(path, params = {})
    uri = Addressable::URI.parse(Rails.application.credentials.imgix.url)
    uri.path = path
    if params.present?
      uri.query_values = params.compact.merge(uri.query_values || {})
    end
    uri.to_s
  end

  def build_imgix_provider_folder_url(path, params = {})
    uri = Addressable::URI.parse(Rails.application.credentials.imgix_folder.url)
    uri.path = path
    if params.present?
      uri.query_values = params.compact.merge(uri.query_values || {})
    end
    uri.to_s
  end

  def build_imgix_provider_video_url(path, params = {})
    uri = Addressable::URI.parse(Rails.application.credentials.imgix_video.url)
    uri.path = path
    if params.present?
      uri.query_values = params.compact.merge(uri.query_values || {})
    end
    uri.to_s
  end

  # Cloudflare CDN provider implementation
  def build_cloudflare_provider_url(path, params = {})
    base = Rails.application.credentials.dig(:cloudflare, :cdn_base_url)
    return path unless base.present?

    uri = Addressable::URI.parse(base)
    uri.path = [uri.path, path].join('/').gsub(%r{/+}, '/')
    
    # Translate Imgix parameters to Cloudflare Image Resizing parameters
    translated_params = translate_imgix_to_cloudflare_params(params)
    uri.query_values = (uri.query_values || {}).merge(translated_params) if translated_params.present?
    uri.to_s
  end

  # Translates Imgix query parameters to Cloudflare Image Resizing parameters
  # This allows backward compatibility when migrating from Imgix to Cloudflare
  def translate_imgix_to_cloudflare_params(params)
    return {} if params.blank?

    cloudflare_params = {}

    params.each do |key, value|
      case key.to_s
      # Dimension parameters
      when 'w'
        cloudflare_params['width'] = value
      when 'h'
        cloudflare_params['height'] = value
      when 'dpr'
        # Cloudflare doesn't have native DPR support, but we can scale dimensions
        # Store for potential dimension multiplication if width/height are also present
        cloudflare_params['dpr'] = value
      
      # Quality parameter
      when 'q', 'quality'
        cloudflare_params['quality'] = value
      
      # Format and compression
      when 'auto'
        # Imgix auto=compress,format → Cloudflare format=auto
        if value.to_s.include?('format')
          cloudflare_params['format'] = 'auto'
        end
      when 'fm', 'format'
        cloudflare_params['format'] = value
      
      # Fit/crop parameters
      when 'fit'
        # Imgix and Cloudflare both support: crop, contain, cover, fill, scale-down
        cloudflare_params['fit'] = value
      when 'crop'
        # Imgix crop modes (e.g., faces, entropy) - Cloudflare uses 'gravity'
        cloudflare_params['gravity'] = translate_crop_to_gravity(value)
      
      # Background color
      when 'bg', 'background'
        cloudflare_params['background'] = value
      
      # Blur
      when 'blur'
        cloudflare_params['blur'] = value
      
      # Brightness, contrast, gamma, sharpen
      when 'bri', 'brightness'
        cloudflare_params['brightness'] = value
      when 'con', 'contrast'
        cloudflare_params['contrast'] = value
      when 'gam', 'gamma'
        cloudflare_params['gamma'] = value
      when 'sharp', 'sharpen'
        cloudflare_params['sharpen'] = value
      
      # Rotation
      when 'rot', 'rotate'
        cloudflare_params['rotate'] = value
      
      # Border
      when 'border'
        cloudflare_params['border'] = value
      
      # Metadata
      when 'metadata'
        cloudflare_params['metadata'] = value
      
      # Blend/overlay parameters (limited Cloudflare support)
      when 'blend-color'
        # Cloudflare doesn't have native blend, but we can pass through for custom handling
        cloudflare_params['blend-color'] = value
      
      # Pass through any Cloudflare-native parameters
      when 'width', 'height', 'gravity', 'anim', 'compression', 'onerror', 'trim'
        cloudflare_params[key.to_s] = value
      
      # Unknown parameters - pass through as-is (might be custom or future params)
      else
        cloudflare_params[key.to_s] = value
      end
    end

    # Apply DPR scaling if both DPR and dimensions are present
    if cloudflare_params['dpr']
      dpr = cloudflare_params['dpr'].to_f
      cloudflare_params['width'] = (cloudflare_params['width'].to_i * dpr).to_i if cloudflare_params['width']
      cloudflare_params['height'] = (cloudflare_params['height'].to_i * dpr).to_i if cloudflare_params['height']
      cloudflare_params.delete('dpr') # Remove DPR as it's been applied
    end

    cloudflare_params
  end

  # Translate Imgix crop modes to Cloudflare gravity values
  def translate_crop_to_gravity(crop_value)
    case crop_value.to_s
    when 'faces', 'face'
      'auto' # Cloudflare auto-detects faces
    when 'entropy', 'edges'
      'auto' # Use auto for content-aware cropping
    when 'top'
      'top'
    when 'bottom'
      'bottom'
    when 'left'
      'left'
    when 'right'
      'right'
    when 'center'
      'center'
    else
      'auto'
    end
  end
end

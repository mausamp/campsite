# frozen_string_literal: true

class CdnController < ApplicationController
  include ActionController::Live

  # Skip ALL authentication and security checks for public CDN access
  skip_before_action :verify_authenticity_token
  skip_before_action :require_authenticated_user, raise: false

  # CRITICAL: Skip any SSL enforcement to prevent redirect loops
  # Cloudflare handles SSL termination, Rails should accept the request as-is
  before_action :accept_cloudflare_ssl

  # Handle CORS preflight requests
  def options
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, HEAD, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Origin, X-Requested-With, Content-Type, Accept"
    head :ok
  end

  def show
    key = params[:path]
    bucket = Rails.application.credentials.dig(:aws, :s3_bucket)

    # Log transformation params for debugging (Cloudflare will handle these)
    if params[:w] || params[:h] || params[:q] || params[:format] || params[:width] || params[:height]
      Rails.logger.debug "[CdnController] Image transformation params: #{params.slice(:w, :h, :q, :format, :width, :height, :quality).inspect}"
    end

    # Fetch object from S3
    s3_object = s3_client.get_object(bucket: bucket, key: key)

    # Common cache headers for Cloudflare
    response.headers["Cache-Control"]  = "public, max-age=31536000, immutable"
    response.headers["ETag"]           = s3_object.etag
    response.headers["Last-Modified"]  = s3_object.last_modified.httpdate
    response.headers["Content-Type"]   = s3_object.content_type
    response.headers["Content-Disposition"] = "inline"
    
    # CORS headers for browser access
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, HEAD, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Origin, X-Requested-With, Content-Type, Accept"

    # Stream the object directly - no transformation in Rails
    # Cloudflare Image Resizing will handle transformations based on query params
    s3_object.body.each { |chunk| response.stream.write(chunk) }
  rescue Aws::S3::Errors::NoSuchKey
    Rails.logger.warn "[CdnController] S3 object not found: #{key}"
    render plain: "File not found", status: :not_found
  rescue StandardError => e
    Rails.logger.error "[CdnController] Error streaming S3 object #{key}: #{e.class}: #{e.message}"
    render plain: "Internal server error", status: :internal_server_error
  ensure
    response.stream.close if response.stream
  end

  private

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      access_key_id:     Rails.application.credentials.dig(:aws, :access_key_id),
      secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key),
      region:            Rails.application.credentials.dig(:aws, :region),
      endpoint:          Rails.application.credentials.dig(:aws, :endpoint),
      force_path_style:  true,
      ssl_verify_peer:   ssl_verify_enabled?,
      ssl_ca_bundle:     ssl_ca_bundle_path
    )
  end

  def ssl_verify_enabled?
    # Disable SSL verification in development/test, enable in production
    !Rails.env.development? && !Rails.env.test?
  end

  def ssl_ca_bundle_path
    # Common CA bundle paths
    [
      "/etc/ssl/certs/ca-certificates.crt", # Debian/Ubuntu
      "/etc/pki/tls/certs/ca-bundle.crt",   # RHEL/CentOS
      "/etc/ssl/ca-bundle.pem",             # OpenSUSE
      "/etc/ssl/cert.pem"                   # macOS/Alpine
    ].find { |path| File.exist?(path) }
  end

  def accept_cloudflare_ssl
    if request.headers['X-Forwarded-Proto'] == 'https' || request.headers['CF-Visitor']&.include?('"scheme":"https"')
      request.env['rack.url_scheme'] = 'https'
      request.env['HTTPS'] = 'on'
    end

    # Optional: log request info for debugging
    Rails.logger.debug "[CdnController] CDN request: #{request.method} #{request.fullpath} Host: #{request.host} Scheme: #{request.scheme}"
  end
end

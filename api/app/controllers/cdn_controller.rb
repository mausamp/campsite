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

    # Transformation params
    width    = params[:w]&.to_i
    height   = params[:h]&.to_i
    quality  = (params[:q] || 80).to_i

    # Fetch object from S3
    s3_object = s3_client.get_object(bucket: bucket, key: key)

    # Common cache headers for Cloudflare
    response.headers["Cache-Control"]  = "public, max-age=31536000, immutable"
    response.headers["ETag"]           = s3_object.etag
    response.headers["Last-Modified"]  = s3_object.last_modified.httpdate
    response.headers["Content-Disposition"] = "inline"
    
    # CORS headers for browser access
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, HEAD, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Origin, X-Requested-With, Content-Type, Accept"

    if image?(s3_object) && (width&.positive? || height&.positive?)
      transformed = transform_image(s3_object, width, height, quality)
      response.headers["Content-Type"] = transformed.mime_type
      send_data transformed.to_blob, disposition: "inline"
    else
      response.headers["Content-Type"] = s3_object.content_type
      s3_object.body.each { |chunk| response.stream.write(chunk) }
    end
  rescue Aws::S3::Errors::NoSuchKey
    render plain: "File not found", status: :not_found
  ensure
    response.stream.close
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
    # Try to find system CA bundle (common paths)
    # Override with ENV var or credentials if needed
    return ENV['SSL_CERT_FILE'] if ENV['SSL_CERT_FILE'].present?
    
    [
      '/etc/ssl/certs/ca-certificates.crt',  # Debian/Ubuntu
      '/etc/pki/tls/certs/ca-bundle.crt',    # RedHat/CentOS
      '/etc/ssl/cert.pem',                    # Alpine/macOS
    ].find { |path| File.exist?(path) }
  end

  def image?(s3_object)
    content_type = s3_object.content_type
    content_type&.start_with?("image/")
  end

  def transform_image(s3_object, width, height, quality)
    # Save to temp file for MiniMagick
    temp = Tempfile.new(["cdn", File.extname(s3_object.key)])
    temp.binmode
    temp.write(s3_object.body.read)
    temp.rewind

    img = MiniMagick::Image.open(temp.path)
    resize_str = [width.presence || "", height.presence || ""].join("x")
    img.resize(resize_str) if resize_str.present?
    img.quality quality.to_s

    img
  ensure
    temp.close
    temp.unlink
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

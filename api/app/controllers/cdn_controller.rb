# frozen_string_literal: true

class CdnController < ApplicationController
  include ActionController::Live

  # Skip authentication and CSRF checks for public CDN
  skip_before_action :verify_authenticity_token
  skip_before_action :require_authenticated_user, raise: false

  # Treat Cloudflare HTTPS requests as secure
  # before_action :accept_cloudflare_ssl

  # Handle CORS preflight requests
  def options
    set_cors_headers
    head :ok
  end

  def show
    key = params[:path]
    bucket = Rails.application.credentials.dig(:aws, :s3_bucket)

    # Fetch object from S3
    s3_object = s3_client.get_object(bucket: bucket, key: key)

    # Set headers
    response.headers["Cache-Control"]  = "public, max-age=31536000, immutable"
    response.headers["ETag"]           = s3_object.etag
    response.headers["Last-Modified"]  = s3_object.last_modified.httpdate
    response.headers["Content-Type"]   = s3_object.content_type
    response.headers["Content-Disposition"] = "inline"
    set_cors_headers

    # Stream the object
    s3_object.body.each { |chunk| response.stream.write(chunk) }
  rescue Aws::S3::Errors::NoSuchKey
    render plain: "File not found", status: :not_found
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
      force_path_style:  true
    )
  end

  # def accept_cloudflare_ssl
  #   if request.headers['X-Forwarded-Proto'] == 'https' || request.headers['CF-Visitor']&.include?('"scheme":"https"')
  #     request.env['rack.url_scheme'] = 'https'
  #     request.env['HTTPS'] = 'on'
  #   end
  # end

  def set_cors_headers
    response.headers["Access-Control-Allow-Origin"]  = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, HEAD, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Origin, X-Requested-With, Content-Type, Accept"
  end
end

# frozen_string_literal: true

class CdnController < ApplicationController
  include ActionController::Live

  def show
    key = params[:path]
    bucket = Rails.application.credentials.dig(:aws, :s3_bucket)

    # Fetch object from S3
    s3_object = s3_client.get_object(bucket: bucket, key: key)

    # Set cache and content headers
    response.headers["Cache-Control"]  = "public, max-age=31536000, immutable"
    response.headers["ETag"]           = s3_object.etag
    response.headers["Last-Modified"]  = s3_object.last_modified.httpdate
    response.headers["Content-Type"]   = s3_object.content_type
    response.headers["Content-Disposition"] = "inline"

    # Cloudflare Image Resizing will handle transformations based on query params
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
end


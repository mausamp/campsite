# frozen_string_literal: true

require "test_helper"

class CdnControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bucket = Rails.application.credentials.dig(:aws, :s3_bucket)
    @s3_client = Aws::S3::Client.new(
      access_key_id:     Rails.application.credentials.dig(:aws, :access_key_id),
      secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key),
      region:            Rails.application.credentials.dig(:aws, :region),
      endpoint:          Rails.application.credentials.dig(:aws, :endpoint),
      force_path_style:  true
    )
  end

  context "#show" do
    test "returns file from S3 with correct headers" do
      file_key = "test/image.jpg"
      file_content = "fake image content"
      content_type = "image/jpeg"
      etag = '"abc123"'
      last_modified = Time.now.utc

      # Mock S3 response
      s3_object = mock("s3_object")
      s3_object.stubs(:body).returns(StringIO.new(file_content))
      s3_object.stubs(:etag).returns(etag)
      s3_object.stubs(:last_modified).returns(last_modified)
      s3_object.stubs(:content_type).returns(content_type)

      s3_client = mock("s3_client")
      s3_client.expects(:get_object).with(bucket: @bucket, key: file_key).returns(s3_object)

      controller = CdnController.new
      controller.stubs(:s3_client).returns(s3_client)
      CdnController.any_instance.stubs(:s3_client).returns(s3_client)

      get cdn_file_path(file_key)

      assert_response :success
      assert_equal file_content, response.body
      assert_equal content_type, response.headers["Content-Type"]
      assert_equal etag, response.headers["ETag"]
      assert_equal last_modified.httpdate, response.headers["Last-Modified"]
      assert_equal "max-age=31536000, public, immutable", response.headers["Cache-Control"]
      assert_equal "inline", response.headers["Content-Disposition"]
    end

    test "returns 404 when file not found in S3" do
      file_key = "test/nonexistent.jpg"

      s3_client = mock("s3_client")
      s3_client.expects(:get_object).with(bucket: @bucket, key: file_key).raises(Aws::S3::Errors::NoSuchKey.new("context", "message"))

      CdnController.any_instance.stubs(:s3_client).returns(s3_client)

      get cdn_file_path(file_key)

      assert_response :not_found
      assert_equal "File not found", response.body
    end

    test "handles nested paths correctly" do
      file_key = "o/org-123/posts/post-456/image.png"
      file_content = "nested image"
      content_type = "image/png"

      s3_object = mock("s3_object")
      s3_object.stubs(:body).returns(StringIO.new(file_content))
      s3_object.stubs(:etag).returns('"nested123"')
      s3_object.stubs(:last_modified).returns(Time.now.utc)
      s3_object.stubs(:content_type).returns(content_type)

      s3_client = mock("s3_client")
      s3_client.expects(:get_object).with(bucket: @bucket, key: file_key).returns(s3_object)

      CdnController.any_instance.stubs(:s3_client).returns(s3_client)

      get cdn_file_path(file_key)

      assert_response :success
      assert_equal file_content, response.body
      assert_equal content_type, response.headers["Content-Type"]
    end

    test "handles files with special characters in path" do
      file_key = "test/file with spaces.jpg"
      file_content = "special char content"

      s3_object = mock("s3_object")
      s3_object.stubs(:body).returns(StringIO.new(file_content))
      s3_object.stubs(:etag).returns('"special123"')
      s3_object.stubs(:last_modified).returns(Time.now.utc)
      s3_object.stubs(:content_type).returns("image/jpeg")

      s3_client = mock("s3_client")
      s3_client.expects(:get_object).with(bucket: @bucket, key: file_key).returns(s3_object)

      CdnController.any_instance.stubs(:s3_client).returns(s3_client)

      get cdn_file_path(file_key)

      assert_response :success
      assert_equal file_content, response.body
    end

    test "handles different content types correctly" do
      test_cases = [
        { key: "test/video.mp4", content_type: "video/mp4", content: "video content" },
        { key: "test/document.pdf", content_type: "application/pdf", content: "pdf content" },
        { key: "test/style.css", content_type: "text/css", content: "css content" },
        { key: "test/data.json", content_type: "application/json", content: '{"key":"value"}' },
      ]

      test_cases.each do |test_case|
        s3_object = mock("s3_object")
        s3_object.stubs(:body).returns(StringIO.new(test_case[:content]))
        s3_object.stubs(:etag).returns('"etag123"')
        s3_object.stubs(:last_modified).returns(Time.now.utc)
        s3_object.stubs(:content_type).returns(test_case[:content_type])

        s3_client = mock("s3_client")
        s3_client.expects(:get_object).with(bucket: @bucket, key: test_case[:key]).returns(s3_object)

        CdnController.any_instance.stubs(:s3_client).returns(s3_client)

        get cdn_file_path(test_case[:key])

        assert_response :success, "Failed for #{test_case[:content_type]}"
        assert_equal test_case[:content], response.body
        assert_equal test_case[:content_type], response.headers["Content-Type"]
      end
    end
  end
end

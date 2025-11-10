# frozen_string_literal: true

require "test_helper"

class MediaUrlBuilderTest < ActiveSupport::TestCase
  class TestClass
    include MediaUrlBuilder
  end

  setup do
    @test_instance = TestClass.new
  end

  context "cdn_provider" do
    test "returns :cloudflare when media provider is set to cloudflare" do
      Rails.application.credentials.stubs(:dig).with(:media, :provider).returns("cloudflare")
      
      assert_equal :cloudflare, @test_instance.cdn_provider
    end

    test "returns :imgix when media provider is set to imgix" do
      Rails.application.credentials.stubs(:dig).with(:media, :provider).returns("imgix")
      
      assert_equal :imgix, @test_instance.cdn_provider
    end

    test "defaults to :cloudflare when media provider is not set" do
      Rails.application.credentials.stubs(:dig).with(:media, :provider).returns(nil)
      
      assert_equal :cloudflare, @test_instance.cdn_provider
    end
  end

  context "fallback_avatar" do
    test "returns a fallback avatar URL with color based on name" do
      @test_instance.stubs(:cdn_provider).returns(:cloudflare)
      Rails.application.credentials.stubs(:dig).with(:cloudflare, :cdn_url).returns("https://cdn.example.com")
      
      url = @test_instance.fallback_avatar("John")
      
      assert_match %r{https://cdn.example.com/cdn/static/avatars/J.png}, url
      assert_match %r{blend-color=}, url
    end

    test "returns blank avatar for empty name" do
      @test_instance.stubs(:cdn_provider).returns(:cloudflare)
      Rails.application.credentials.stubs(:dig).with(:cloudflare, :cdn_url).returns("https://cdn.example.com")
      
      url = @test_instance.fallback_avatar("")
      
      assert_match %r{static/avatars/blank.png}, url
    end

    test "generates consistent color for same name" do
      @test_instance.stubs(:cdn_provider).returns(:cloudflare)
      Rails.application.credentials.stubs(:dig).with(:cloudflare, :cdn_url).returns("https://cdn.example.com")
      
      url1 = @test_instance.fallback_avatar("Alice")
      url2 = @test_instance.fallback_avatar("Alice")
      
      assert_equal url1, url2
    end
  end

  context "build_media_url with Cloudflare" do
    setup do
      @test_instance.stubs(:cdn_provider).returns(:cloudflare)
    end

    test "builds basic Cloudflare CDN URL" do
      Rails.application.credentials.stubs(:dig).with(:cloudflare, :cdn_url).returns("https://cdn.polo-apps.com")
      
      url = @test_instance.build_media_url("images/photo.jpg")

      assert_equal "https://cdn.polo-apps.com/cdn/images/photo.jpg", url
    end
  end

  context "build_media_url with Imgix" do
    setup do
      @test_instance.stubs(:cdn_provider).returns(:imgix)
    end

    test "builds basic Imgix URL" do
      Rails.application.credentials.stubs(:dig).with(:imgix, :url).returns("https://polo-apps.imgix.net")
      
      url = @test_instance.build_media_url("images/photo.jpg")

      assert_equal "https://polo-apps.imgix.net/images/photo.jpg", url
    end
  end

  context "build_media_folder_url with Cloudflare" do
    setup do
      @test_instance.stubs(:cdn_provider).returns(:cloudflare)
    end

    test "builds folder URL using folder_cdn_url if available" do
      Rails.application.credentials.stubs(:dig).with(:cloudflare, :folder_cdn_url).returns("https://folder.polo-apps.com")
      Rails.application.credentials.stubs(:dig).with(:cloudflare, :cdn_url).returns("https://cdn.polo-apps.com")

      url = @test_instance.build_media_folder_url("folders/image.jpg")

      assert_match %r{https://folder.polo-apps.com}, url
    end

    test "falls back to main cdn_url if folder_cdn_url not available" do
      Rails.application.credentials.stubs(:dig).with(:cloudflare, :folder_cdn_url).returns(nil)
      Rails.application.credentials.stubs(:dig).with(:cloudflare, :cdn_url).returns("https://cdn.polo-apps.com")

      url = @test_instance.build_media_folder_url("folders/image.jpg")

      assert_match %r{https://cdn.polo-apps.com}, url
    end
  end

  context "build_media_folder_url with Imgix" do
    setup do
      @test_instance.stubs(:cdn_provider).returns(:imgix)
    end

    test "builds folder URL using imgix_folder url if available" do
      Rails.application.credentials.stubs(:dig).with(:imgix_folder, :url).returns("https://folder.polo-apps.imgix.net")
      Rails.application.credentials.stubs(:dig).with(:imgix, :url).returns("https://polo-apps.imgix.net")
      
      url = @test_instance.build_media_folder_url("folders/image.jpg")

      assert_equal "https://folder.polo-apps.imgix.net/folders/image.jpg", url
    end

    test "falls back to main imgix url if folder url not available" do
      Rails.application.credentials.stubs(:dig).with(:imgix_folder, :url).returns(nil)
      Rails.application.credentials.stubs(:dig).with(:imgix, :url).returns("https://polo-apps.imgix.net")

      url = @test_instance.build_media_folder_url("folders/image.jpg")

      assert_equal "https://polo-apps.imgix.net/folders/image.jpg", url
    end
  end

  context "build_media_video_url with Cloudflare" do
    setup do
      @test_instance.stubs(:cdn_provider).returns(:cloudflare)
    end

    test "builds video URL using video_cdn_url if available" do
      Rails.application.credentials.stubs(:dig).with(:cloudflare, :video_cdn_url).returns("https://video.polo-apps.com")
      Rails.application.credentials.stubs(:dig).with(:cloudflare, :cdn_url).returns("https://cdn.polo-apps.com")

      url = @test_instance.build_media_video_url("videos/clip.mp4")

      assert_match %r{https://video.polo-apps.com}, url
    end

    test "falls back to main cdn_url if video_cdn_url not available" do
      Rails.application.credentials.stubs(:dig).with(:cloudflare, :video_cdn_url).returns(nil)
      Rails.application.credentials.stubs(:dig).with(:cloudflare, :cdn_url).returns("https://cdn.polo-apps.com")

      url = @test_instance.build_media_video_url("videos/clip.mp4")

      assert_match %r{https://cdn.polo-apps.com}, url
    end
  end

  context "build_media_video_url with Imgix" do
    setup do
      @test_instance.stubs(:cdn_provider).returns(:imgix)
    end

    test "builds video URL using imgix_video url if available" do
      Rails.application.credentials.stubs(:dig).with(:imgix_video, :url).returns("https://video.polo-apps.imgix.net")
      Rails.application.credentials.stubs(:dig).with(:imgix, :url).returns("https://polo-apps.imgix.net")

      url = @test_instance.build_media_video_url("videos/clip.mp4", { "video-generate": "thumbnail" })

      assert_match %r{https://video.polo-apps.imgix.net/videos/clip.mp4}, url
      assert_match %r{video-generate=thumbnail}, url
    end

    test "falls back to main imgix url if video url not available" do
      Rails.application.credentials.stubs(:dig).with(:imgix_video, :url).returns(nil)
      Rails.application.credentials.stubs(:dig).with(:imgix, :url).returns("https://polo-apps.imgix.net")
      
      url = @test_instance.build_media_video_url("videos/clip.mp4")

      assert_equal "https://polo-apps.imgix.net/videos/clip.mp4", url
    end
  end
end

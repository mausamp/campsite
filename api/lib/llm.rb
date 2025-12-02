# frozen_string_literal: true

class Llm
  DEFAULT_MODELS = {
    openai: "gpt-4o-mini",
    gemini: "gemini-2.5-flash",
    anthropic: "claude-3-5-haiku-20241022",
  }.freeze

  # Provider aliases for convenience
  PROVIDER_ALIASES = {
    google: :gemini,
    claude: :anthropic,
    openai: :openai,
    gpt: :openai,
  }.freeze

  attr_reader :provider, :model, :client

  def initialize(provider: :gemini, model: nil)
    @provider = normalize_provider(provider)
    @model = model || DEFAULT_MODELS[@provider] || DEFAULT_MODELS[:gemini]
    @client = create_client
  end

  def chat(messages:, &block)
    chat_client = RubyLLM.chat(model: @model, provider: @provider)

    if block_given?
      chat_client.ask(messages, &block)
    else
      response = chat_client.ask(messages)
      response.content
    end
  rescue StandardError => e
    Rails.logger.error("LLM Error [#{@provider}/#{@model}]: #{e.message}")
    raise
  end

  def self.provider_configured?(provider)
    provider_sym = provider.to_s.downcase.to_sym
    normalized = PROVIDER_ALIASES[provider_sym] || provider_sym

    case normalized
    when :openai
      RubyLLM.config.openai_api_key.present?
    when :gemini
      RubyLLM.config.gemini_api_key.present?
    when :anthropic
      RubyLLM.config.anthropic_api_key.present?
    else
      false
    end
  rescue StandardError
    false
  end

  def self.available_providers
    [:openai, :gemini, :anthropic].select { |p| provider_configured?(p) }
  end

  private

  def normalize_provider(provider)
    provider_sym = provider.to_s.downcase.to_sym
    PROVIDER_ALIASES[provider_sym] || provider_sym
  end

  def create_client
    unless self.class.provider_configured?(@provider)
      available = self.class.available_providers
      if available.empty?
        raise StandardError, "No LLM providers configured. Please set API keys in config/initializers/ruby_llm.rb"
      else
        Rails.logger.warn("Provider #{@provider} not configured, available: #{available.join(", ")}")
      end
    end

    :ruby_llm
  end
end

# frozen_string_literal: true

ENV["ELASTICSEARCH_URL"] = if Rails.env.production?
  "http://127.0.0.1:9300"
else
  "http://localhost:9200"
end

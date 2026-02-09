require "test_helper"

class AiDataWebSearchFetchTest < ActiveSupport::TestCase
  class StubResponses
    def initialize(response)
      @response = response
    end

    def create(**_kwargs)
      @response
    end
  end

  class StubClient
    attr_reader :responses

    def initialize(response)
      @responses = StubResponses.new(response)
    end
  end

  test "replaces homepage source with citation deep link on same host" do
    response_payload = {
      "query_summary" => "3-day forecast in Vienna",
      "as_of_date" => "2026-02-09",
      "dataset" => nil,
      "sources" => [
        { "title" => "Weather.com", "url" => "https://weather.com/" }
      ],
      "notes" => nil
    }

    response = {
      "output_text" => response_payload.to_json,
      "output" => [
        {
          "content" => [
            {
              "type" => "output_text",
              "annotations" => [
                {
                  "type" => "url_citation",
                  "title" => "Vienna 3-day weather forecast",
                  "url" => "https://weather.com/weather/tenday/l/Vienna+Austria"
                }
              ]
            }
          ]
        }
      ]
    }

    result = build_service(response).call(query_text: "3 day weather forecast vienna")

    assert_equal true, result[:ok]
    assert_equal "https://weather.com/weather/tenday/l/Vienna+Austria", result.dig(:sources_json, 0, "url")
  end

  test "keeps explicit deep link source as is" do
    response_payload = {
      "query_summary" => "3-day forecast in Vienna",
      "as_of_date" => "2026-02-09",
      "dataset" => nil,
      "sources" => [
        { "title" => "Meteo", "url" => "https://www.meteo.example/forecast/vienna" }
      ],
      "notes" => nil
    }

    response = {
      "output_text" => response_payload.to_json,
      "output" => [
        {
          "content" => [
            {
              "type" => "output_text",
              "annotations" => [
                {
                  "type" => "url_citation",
                  "title" => "Other page",
                  "url" => "https://www.meteo.example/some/other/page"
                }
              ]
            }
          ]
        }
      ]
    }

    result = build_service(response).call(query_text: "3 day weather forecast vienna")

    assert_equal true, result[:ok]
    assert_equal "https://www.meteo.example/forecast/vienna", result.dig(:sources_json, 0, "url")
  end

  test "uses citation source when model payload has no sources" do
    response_payload = {
      "query_summary" => "3-day forecast in Vienna",
      "as_of_date" => "2026-02-09",
      "dataset" => nil,
      "sources" => [],
      "notes" => nil
    }

    response = {
      "output_text" => response_payload.to_json,
      "output" => [
        {
          "content" => [
            {
              "type" => "output_text",
              "annotations" => [
                {
                  "type" => "url_citation",
                  "title" => "Vienna 3-day weather forecast",
                  "url" => "https://weather.example/forecast/vienna"
                }
              ]
            }
          ]
        }
      ]
    }

    result = build_service(response).call(query_text: "3 day weather forecast vienna")

    assert_equal true, result[:ok]
    assert_equal "https://weather.example/forecast/vienna", result.dig(:sources_json, 0, "url")
  end

  private

  def build_service(response)
    Ai::Data::WebSearchFetch.new(
      client: StubClient.new(response),
      tool_candidates: ["web_search_preview"]
    )
  end
end

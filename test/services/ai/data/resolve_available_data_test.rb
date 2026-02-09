require "test_helper"
require "ostruct"

class AiDataResolveAvailableDataTest < ActiveSupport::TestCase
  class StubFetcher
    attr_reader :calls

    def initialize(response:)
      @response = response
      @calls = []
    end

    def call(**kwargs)
      @calls << kwargs
      @response
    end
  end

  test "returns not_needed when metadata says no sources and query has no source signal" do
    user_message, chat = create_message("write a short welcome paragraph")
    fetcher = StubFetcher.new(response: { ok: true })

    resolver = Ai::Data::ResolveAvailableData.new(
      context: build_context(user_message, chat, { needs_sources: false, suggest_web_search: false }),
      fetcher: fetcher
    )

    result = resolver.call

    assert_equal "not_needed", result[:decision]
    assert_equal false, result[:needed]
    assert_equal 0, fetcher.calls.length
  end

  test "uses cache when sources are needed and signature matches" do
    user_message, chat = create_message("gdp for austria over 5 years until today")
    key = Ai::Data::SourceCacheKey.call(user_message.instruction)

    DataSourceCache.create!(
      company: chat.company,
      chat: chat,
      query_signature: key[:query_signature],
      query_text: user_message.instruction,
      data_json: {
        "query" => user_message.instruction,
        "dataset" => { "version" => 1, "datasets" => [] }
      },
      sources_json: [{ "title" => "World Bank", "url" => "https://data.worldbank.org/" }],
      last_fetched_at: Time.current
    )

    fetcher = StubFetcher.new(response: { ok: true })

    resolver = Ai::Data::ResolveAvailableData.new(
      context: build_context(user_message, chat, { needs_sources: true, suggest_web_search: true }),
      fetcher: fetcher
    )

    result = resolver.call

    assert_equal "use_cache", result[:decision]
    assert_equal true, result[:needed]
    assert_equal 0, fetcher.calls.length
    assert_equal "https://data.worldbank.org/", result.dig(:available_data, "sources", 0, "url")
  end

  test "searches and stores cache on miss when sources are needed" do
    user_message, chat = create_message("gdp for austria over 5 years until today")
    fetcher = StubFetcher.new(
      response: {
        ok: true,
        available_data: {
          "query" => user_message.instruction,
          "as_of_date" => "2026-02-09",
          "dataset" => { "version" => 1, "datasets" => [] },
          "sources" => [{ "title" => "World Bank", "url" => "https://data.worldbank.org/" }]
        },
        sources_json: [{ "title" => "World Bank", "url" => "https://data.worldbank.org/" }]
      }
    )

    resolver = Ai::Data::ResolveAvailableData.new(
      context: build_context(user_message, chat, { needs_sources: true, suggest_web_search: true }),
      fetcher: fetcher
    )

    assert_difference "DataSourceCache.count", 1 do
      result = resolver.call
      assert_equal "search", result[:decision]
      assert_equal true, result[:needed]
      assert_equal "2026-02-09", result.dig(:available_data, "as_of_date")
    end

    cache = DataSourceCache.order(created_at: :desc).first
    assert_equal chat.id, cache.chat_id
    assert_equal "https://data.worldbank.org/", cache.sources_json.first["url"]
    assert_equal 1, fetcher.calls.length
  end

  private

  def create_message(instruction)
    company = Company.create!(name: "Acme", slug: "acme-#{SecureRandom.hex(4)}", status: "active")
    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com", password: "password123")
    chat = Chat.create!(company: company, created_by: user, title: "Data chat", status: "active")
    user_message = UserMessage.create!(
      company: company,
      created_by: user,
      chat: chat,
      instruction: instruction,
      status: "queued"
    )

    [user_message, chat]
  end

  def build_context(user_message, chat, meta)
    OpenStruct.new(
      user_message: user_message,
      chat: chat,
      meta: meta,
      model: "gpt-5.2",
      context_text: ""
    )
  end
end

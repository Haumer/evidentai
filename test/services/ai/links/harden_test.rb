require "test_helper"

class AiLinksHardenTest < ActiveSupport::TestCase
  test "adds target blank and safe rel tokens" do
    html = '<p><a href="https://example.com">Example</a></p>'

    out = Ai::Links::Harden.call(html, target_blank: true)

    assert_includes out, 'target="_blank"'
    assert_includes out, 'rel="noopener noreferrer"'
  end

  test "preserves existing rel tokens while appending safe tokens" do
    html = '<a href="https://example.com" rel="nofollow">Example</a>'

    out = Ai::Links::Harden.call(html, target_blank: true)

    assert_includes out, 'rel="nofollow noopener noreferrer"'
  end

  test "removes javascript hrefs" do
    html = '<a href="javascript:alert(1)">Bad</a>'

    out = Ai::Links::Harden.call(html, target_blank: true)

    assert_includes out, "<a"
    assert_not_includes out, "href="
    assert_includes out, 'target="_blank"'
  end

  test "works with full html documents" do
    html = <<~HTML
      <html>
        <head><title>x</title></head>
        <body><a href="https://example.com">Go</a></body>
      </html>
    HTML

    out = Ai::Links::Harden.call(html, target_blank: true)

    assert_includes out, "<html"
    assert_includes out, 'target="_blank"'
  end
end

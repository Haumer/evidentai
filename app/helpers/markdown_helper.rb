# app/helpers/markdown_helper.rb

module MarkdownHelper
  def render_markdown(text)
    cleaned = Ai::Chat::CleanReplyText.call(text.to_s)
    md = normalize_utf8(strip_wrapping_fence(cleaned))

    if defined?(CommonMarker)
      html = CommonMarker.render_html(
        md,
        :DEFAULT,
        %i[table strikethrough autolink tasklist]
      )
      return sanitize_markdown_html(html)
    end

    # If you're using a different gem named Commonmarker, support it too.
    if defined?(Commonmarker) && Commonmarker.respond_to?(:to_html)
      html = Commonmarker.to_html(md, options: { parse: { smart: true } })
      return sanitize_markdown_html(html)
    end

    simple_format(h(md))
  end

  private

  # Removes a single outer ```lang ... ``` wrapper if the entire string is fenced.
  def strip_wrapping_fence(md)
    s = md.to_s.strip
    return s unless s.start_with?("```") && s.end_with?("```")

    lines = s.split("\n")
    return s if lines.length < 3
    return s unless lines.last.to_s.strip == "```"

    opening = lines.first.to_s.strip
    lang = opening.sub(/\A```/, "").strip.downcase
    wrapper_langs = %w[ markdown md text plain plaintext ]

    # Preserve real code fences like ```ruby / ```json.
    return s if lang.present? && !wrapper_langs.include?(lang)

    # Remove first and last fence lines
    inner = lines[1..-2].join("\n")
    inner.strip
  end

  # ✅ Ensure markdown renderer always receives valid UTF-8
  def normalize_utf8(str)
    s = str.to_s

    # Fast path
    return s if s.encoding == Encoding::UTF_8 && s.valid_encoding?

    # If it's binary or invalid, transcode with replacement
    s.encode(
      Encoding::UTF_8,
      invalid: :replace,
      undef: :replace,
      replace: "�"
    )
  rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
    # Absolute fallback
    s.force_encoding(Encoding::UTF_8)
    s.valid_encoding? ? s : s.scrub("�")
  end

  def sanitize_markdown_html(html)
    sanitized = sanitize(
      html,
      tags: %w[
        p br strong em a ul ol li blockquote pre code h1 h2 h3 h4 h5 h6 hr
        table thead tbody tr th td
      ],
      attributes: %w[href title rel target]
    )

    Ai::Links::Harden.call(sanitized, target_blank: true).html_safe
  end
end

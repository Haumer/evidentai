module Ai
  class ProcessUserMessage
    class Context
      attr_accessor :ai_message, :meta, :artifact_updated
      attr_reader :chat, :model, :provider, :user_message

      def initialize(user_message:, context_text:, model:, provider:)
        @user_message = user_message
        @chat = user_message.chat
        @context_text = context_text.to_s.strip
        @model = model
        @provider = provider
        @artifact_updated = false
      end

      def context_text
        return @context_text if @context_text.present?

        settings = @user_message.respond_to?(:settings) && @user_message.settings.is_a?(Hash) ? @user_message.settings : {}
        turns = (settings["context_turns"] || Ai::Context::BuildContext::DEFAULT_TURNS).to_i
        max_chars = (settings["context_max_chars"] || Ai::Context::BuildContext::DEFAULT_MAX_CHARS).to_i

        @context_text = Ai::Context::BuildContext.new(
          chat: @chat,
          exclude_user_message_id: @user_message.id,
          turns: turns,
          max_chars: max_chars
        ).call
      end

      def should_generate_artifact?
        return false if courtesy_only_message?(current_user_text)
        return true if @meta.nil?
        return true if meta_should_generate_artifact?

        follow_up_answer_for_artifact_request?
      rescue
        false
      end

      def full_chat_history_text
        return @full_chat_history_text if defined?(@full_chat_history_text)

        messages = recent_user_messages(include_current: true, limit: nil)
        lines = []
        messages.each_with_index do |message, idx|
          user_text = compact(extract_user_text(message))
          next if user_text.blank?

          lines << "U#{idx + 1}: #{user_text}"

          assistant_text = compact(extract_assistant_text(message))
          lines << "A#{idx + 1}: #{assistant_text}" if assistant_text.present?
        end

        @full_chat_history_text = lines.join("\n").strip
      rescue
        @full_chat_history_text = compact(current_user_text)
      end

      def full_user_history_text
        full_chat_history_text
      end

      private

      def follow_up_answer_for_artifact_request?
        current = current_user_text
        return false if current.blank?
        return false if courtesy_only_message?(current)
        return false unless prior_artifact_request_exists?

        true
      end

      def chat_supports_history?
        @chat.respond_to?(:user_messages) && @chat.user_messages.respond_to?(:where)
      end

      def prior_artifact_request_exists?
        recent_user_messages(include_current: false, limit: nil).any? do |message|
          artifact_request_text?(extract_user_text(message))
        end
      end

      def meta_should_generate_artifact?
        h = @meta.is_a?(Hash) ? @meta : {}
        h[:should_generate_artifact] == true || h["should_generate_artifact"] == true
      end

      def artifact_request_text?(text)
        text.to_s.match?(
          /\b(forecast|summary|summari[sz]e|plan|report|analysis|analy[sz]e|checklist|brief|draft|email|itinerary|timeline|proposal|outline|document|list|locations?|places?|recommend(?:ation|ations)?|top\s+\d+)\b/i
        )
      end

      def courtesy_only_message?(text)
        text.to_s.strip.match?(
          /\A(thanks|thank you|thx|ok|okay|got it|great|sounds good|cool|perfect|nice|awesome|done|understood|all good|looks good)[.!]*\z/i
        )
      end

      def current_user_text
        @user_message.instruction.to_s.strip
      end

      def recent_user_messages(include_current:, limit:)
        return [] unless chat_supports_history?

        scope = @chat.user_messages
        scope = scope.where.not(id: @user_message.id) unless include_current
        scope = scope.order(created_at: :desc) if scope.respond_to?(:order)
        scope = scope.includes(:ai_message) if scope.respond_to?(:includes)
        scope = scope.limit(limit) if limit.present? && scope.respond_to?(:limit)

        messages =
          if scope.respond_to?(:to_a)
            scope.to_a
          elsif scope.respond_to?(:records)
            scope.records
          else
            Array(scope)
          end

        messages.reverse
      rescue
        []
      end

      def extract_user_text(message)
        if message.respond_to?(:instruction)
          message.instruction.to_s
        elsif message.respond_to?(:content)
          message.content.to_s
        else
          message.to_s
        end
      end

      def extract_assistant_text(message)
        return "" unless message.respond_to?(:ai_message)

        ai_message = message.ai_message
        return "" unless ai_message

        if ai_message.respond_to?(:text)
          Ai::Chat::CleanReplyText.call(ai_message.text.to_s)
        else
          ""
        end
      end

      def compact(text)
        text.to_s.gsub(/\s+/, " ").strip
      end
    end
  end
end

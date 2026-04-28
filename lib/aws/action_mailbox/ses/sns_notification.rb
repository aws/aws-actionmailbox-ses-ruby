# frozen_string_literal: true

module Aws
  module ActionMailbox
    module SES
      # @api private
      class SNSNotification
        class MessageContentError < StandardError; end

        def initialize(request_body)
          @request_body = request_body
        end

        def subscription_confirmed?
          (200..299).cover?(confirmation_response.code.to_i)
        end

        def verified?
          SNSMessageVerifier.verifier.authentic?(@request_body)
        end

        def topic
          notification.fetch(:TopicArn)
        end

        def type
          notification.fetch(:Type)
        end

        def message_content
          raise MessageContentError, 'Incoming emails must have notificationType `Received`' unless receipt?

          if content_in_s3?
            s3_content
          else
            return message[:content] unless destination

            "X-Original-To: #{destination}\n#{message[:content]}"
          end
        end

        private

        def notification
          @notification ||= JSON.parse(@request_body, symbolize_names: true)
        rescue JSON::ParserError => e
          Rails.logger.warn("Unable to parse SNS notification: #{e}")
          nil
        end

        def s3_content
          fetch_client
            .get_object(key: key, bucket: bucket)
            .body
            .string
        end

        def fetch_client
          cfg = ::Rails.configuration.action_mailbox.ses
          return S3Client.client unless cfg.decrypt_fallback_to_plain && cfg.s3_client

          meta = S3Client.client_plain.head_object(key: key, bucket: bucket).metadata || {}
          meta.key?('x-amz-key-v2') || meta.key?('x-amz-key') ? S3Client.client : S3Client.client_plain
        end

        def message
          @message ||= JSON.parse(notification[:Message], symbolize_names: true)
        end

        def destination
          message.dig(:mail, :destination)&.first
        end

        def action
          return unless message[:receipt]

          message.fetch(:receipt).fetch(:action)
        end

        def bucket
          action.fetch(:bucketName)
        end

        def key
          action.fetch(:objectKey)
        end

        def content_in_s3?
          action&.fetch(:type) == 'S3'
        end

        def receipt?
          message.fetch(:notificationType) == 'Received'
        end

        def confirmation_response
          @confirmation_response ||= Net::HTTP.get_response(URI(notification[:SubscribeURL]))
        end
      end
    end
  end
end

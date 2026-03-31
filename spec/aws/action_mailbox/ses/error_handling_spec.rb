# frozen_string_literal: true

describe 'error handling', type: :request do
  let(:inbound_email_url) { '/rails/action_mailbox/ses/inbound_emails' }

  before do
    stub_request(
      :get,
      'https://sns.us-west-2.amazonaws.com/SimpleNotificationService-a86cb10b4e1f29c941702d737128f7b6.pem'
    ).and_return(body: fixture_for(:certificate, type: :pem))
  end

  context 'when request body is empty' do
    it 'does not raise DoubleRenderError' do
      expect do
        post inbound_email_url, params: '', headers: { 'Content-Type' => 'application/json' }
      end.not_to raise_error
    end
  end

  context 'when request body is invalid JSON' do
    it 'does not raise DoubleRenderError' do
      expect do
        post inbound_email_url, params: 'not json', headers: { 'Content-Type' => 'application/json' }
      end.not_to raise_error
    end
  end

  context 'when notification has an invalid signature' do
    it 'returns unauthorized without raising DoubleRenderError' do
      post inbound_email_url,
           params: JSON.parse(fixture_for(:invalid_signature, type: :json)),
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when notification has an unrecognized topic' do
    it 'returns unauthorized without raising DoubleRenderError' do
      post inbound_email_url,
           params: JSON.parse(fixture_for(:unrecognized_topic_subscription_request, type: :json)),
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end

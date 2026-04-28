# frozen_string_literal: true

describe 'inbound email', type: :request do
  let(:inbound_email_url) { '/rails/action_mailbox/ses/inbound_emails' }

  before do
    stub_request(
      :get,
      'https://sns.us-west-2.amazonaws.com/SimpleNotificationService-a86cb10b4e1f29c941702d737128f7b6.pem'
    ).and_return(body: fixture_for(:certificate, type: :pem))
  end

  it 'receives inbound email' do
    post inbound_email_url, params: JSON.parse(fixture_for(:inbound_email, type: :json)), as: :json

    expect(response).to have_http_status(:no_content)
    expect(ActionMailbox::InboundEmail.count).to eql 1
  end

  it 'receives an inbound email with data in s3' do
    s3_email = fixture_for(:s3_email, type: :txt)

    s3_client = Aws::S3::Client.new(stub_responses: true)
    s3_client.stub_responses(:head_object, { content_length: s3_email.size, parts_count: 1 })
    s3_client.stub_responses(:get_object, { body: s3_email })

    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)

    expect do
      post inbound_email_url,
           params: JSON.parse(fixture_for(:inbound_email_s3, type: :json)),
           as: :json
    end.to change(ActionMailbox::InboundEmail, :count).by(1)

    expect(response).to have_http_status(:no_content)

    inbound_email = ActionMailbox::InboundEmail.last
    expect(s3_email).to eq(inbound_email.raw_email.download)
  end

  describe 'configurable s3_client' do
    let(:s3_email) { fixture_for(:s3_email, type: :txt) }
    let(:s3_payload) { JSON.parse(fixture_for(:inbound_email_s3, type: :json)) }

    before do
      Aws::ActionMailbox::SES::S3Client.instance_variable_set(:@client, nil)
      Aws::ActionMailbox::SES::S3Client.instance_variable_set(:@client_plain, nil)
    end

    after do
      Aws::ActionMailbox::SES::S3Client.instance_variable_set(:@client, nil)
      Aws::ActionMailbox::SES::S3Client.instance_variable_set(:@client_plain, nil)
      Rails.configuration.action_mailbox.ses.s3_client = nil
      Rails.configuration.action_mailbox.ses.decrypt_fallback_to_plain = false
    end

    it 'uses the configured s3_client for every fetch (fallback disabled)' do
      custom = Aws::S3::Client.new(stub_responses: true)
      custom.stub_responses(:get_object, { body: s3_email })
      default = Aws::S3::Client.new(stub_responses: true)
      allow(Aws::S3::Client).to receive(:new).and_return(default)

      Rails.configuration.action_mailbox.ses.s3_client = custom

      expect(custom).to receive(:get_object).at_least(:once).and_call_original
      expect(default).not_to receive(:head_object)
      expect(default).not_to receive(:get_object)

      post inbound_email_url, params: s3_payload, as: :json
      expect(response).to have_http_status(:no_content)
    end

    it 'falls back to plain client for unencrypted objects when decrypt_fallback_to_plain is true' do
      custom = Aws::S3::Client.new(stub_responses: true)
      default = Aws::S3::Client.new(stub_responses: true)
      default.stub_responses(:head_object, { metadata: {} })
      default.stub_responses(:get_object, { body: s3_email })
      allow(Aws::S3::Client).to receive(:new).and_return(default)

      Rails.configuration.action_mailbox.ses.s3_client = custom
      Rails.configuration.action_mailbox.ses.decrypt_fallback_to_plain = true

      expect(default).to receive(:head_object).at_least(:once).and_call_original
      expect(default).to receive(:get_object).at_least(:once).and_call_original
      expect(custom).not_to receive(:get_object)

      post inbound_email_url, params: s3_payload, as: :json
      expect(response).to have_http_status(:no_content)
    end

    it 'routes to configured client when HEAD shows encryption metadata and fallback is enabled' do
      custom = Aws::S3::Client.new(stub_responses: true)
      custom.stub_responses(:get_object, { body: s3_email })
      default = Aws::S3::Client.new(stub_responses: true)
      default.stub_responses(:head_object, { metadata: { 'x-amz-key-v2' => 'wrapped-dek' } })
      allow(Aws::S3::Client).to receive(:new).and_return(default)

      Rails.configuration.action_mailbox.ses.s3_client = custom
      Rails.configuration.action_mailbox.ses.decrypt_fallback_to_plain = true

      expect(default).to receive(:head_object).at_least(:once).and_call_original
      expect(custom).to receive(:get_object).at_least(:once).and_call_original
      expect(default).not_to receive(:get_object)

      post inbound_email_url, params: s3_payload, as: :json
      expect(response).to have_http_status(:no_content)
    end
  end
end

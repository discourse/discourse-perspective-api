require 'rails_helper'

describe ::Etiquette::PostToxicityController do

  before do
    SiteSetting.etiquette_enabled = true
  end

  let(:api_endpoint) { "https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze?key=" }
  let(:api_response_toxicity_body) { '{"attributeScores": {"TOXICITY": {"spanScores": [{"begin": 0,"end": 11,"score": {"value": 0.015122943,"type": "PROBABILITY"}}],"summaryScore": {"value": 0.015122943,"type": "PROBABILITY"}}},"languages": ["en"]}' }
  let(:api_response_high_toxicity_body) { '{"attributeScores": {"TOXICITY": {"spanScores": [{"begin": 0,"end": 11,"score": {"value": 0.915122943,"type": "PROBABILITY"}}],"summaryScore": {"value": 0.915122943,"type": "PROBABILITY"}}},"languages": ["en"]}' }

  let(:headers) do
    { "ACCEPT" => "applicaiton/json", "HTTP_ACCEPT" => "application/json" }
  end

  let(:post) { Fabricate(:post, user: log_in) }

  describe '.show' do
    it 'returns the score if above threshold' do
      stub_request(:post, api_endpoint).to_return(status: 200, body: api_response_high_toxicity_body, headers: {})
      get '/etiquette/post_toxicity', params: { concat: 'Fuck. This is outrageous and dumb. Go to hell.' }, headers: headers
      json = JSON.parse(response.body)
      expect(json['score']).to eq 0.915122943
    end

    it 'returns nothing if under threshold' do
      stub_request(:post, api_endpoint).to_return(status: 200, body: api_response_toxicity_body, headers: {})
      get '/etiquette/post_toxicity', params: { concat: 'Fuck. This is outrageous and dumb. Go to hell.' }, headers: headers
      json = JSON.parse(response.body)
      expect(json).to eq({})
    end

    it 'returns nothing if any network errors' do
      stub_request(:post, api_endpoint).to_return(status: 403)
      get '/etiquette/post_toxicity', params: { concat: 'Fuck. This is outrageous and dumb. Go to hell.' }, headers: headers
      json = JSON.parse(response.body)
      expect(json).to eq({})
    end
  end
end

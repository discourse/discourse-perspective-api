require 'rails_helper'
require 'fakeweb'

API_ENDPOINT = "https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze?key="
API_RESPONSE_TOXICITY_BODY = '{"attributeScores": {"TOXICITY": {"spanScores": [{"begin": 0,"end": 11,"score": {"value": 0.015122943,"type": "PROBABILITY"}}],"summaryScore": {"value": 0.015122943,"type": "PROBABILITY"}}},"languages": ["en"]}'
API_RESPONSE_HIGH_TOXICITY_BODY = '{"attributeScores": {"TOXICITY": {"spanScores": [{"begin": 0,"end": 11,"score": {"value": 0.915122943,"type": "PROBABILITY"}}],"summaryScore": {"value": 0.915122943,"type": "PROBABILITY"}}},"languages": ["en"]}'
API_RESPONSE_SEVERE_TOXICITY_BODY = '{"attributeScores": {"TOXICITY": {"spanScores": [{"begin": 0,"end": 11,"score": {"value": 0.0053346273,"type": "PROBABILITY"}}],"summaryScore": {"value": 0.0053346273,"type": "PROBABILITY"}}},"languages": ["en"]}'
API_RESPONSE_HIGH_SEVERE_TOXICITY_BODY = '{"attributeScores": {"TOXICITY": {"spanScores": [{"begin": 0,"end": 11,"score": {"value": 0.915122943,"type": "PROBABILITY"}}],"summaryScore": {"value": 0.915122943,"type": "PROBABILITY"}}},"languages": ["en"]}'

describe DiscourseEtiquette do
  let(:post) { Fabricate(:post) }

  describe 'AnalyzeComment' do
    let(:json) { MultiJson.load(DiscourseEtiquette::AnalyzeComment.new(post, post.user_id).to_json).deep_symbolize_keys }

    it 'generates json' do
      expect(json[:comment][:text].blank?).to be_falsey
      expect(json[:requestedAttributes][:TOXICITY][:scoreType].blank?).to be_falsey
    end

    it 'standard etiquette_toxicity_model' do
      SiteSetting.etiquette_toxicity_model = 'standard'
      expect(json[:requestedAttributes][:TOXICITY][:scoreType]).to eq 'PROBABILITY'
    end

    it 'severe toxicity etiquette_toxicity_model' do
      SiteSetting.etiquette_toxicity_model = 'severe toxicity (experimental)'
      expect(json[:requestedAttributes][:SEVERE_TOXICITY][:scoreType]).to eq 'PROBABILITY'
    end
  end

  describe ".unload_json" do
    it 'returns an empty dict at least' do
      expect(DiscourseEtiquette.unload_json('')).to eq({})
    end
  end

  describe '.extract_value_from_analyze_comment_response' do
    let(:toxicity_response) { '{ "attributeScores": { "TOXICITY": { "spanScores": [ { "begin": 0, "end": 80, "score": { "value": 0.026585817, "type": "PROBABILITY" } } ], "summaryScore": { "value": 0.026585817, "type": "PROBABILITY" } } }, "languages": [ "en" ] }' }
    let(:severe_toxicity_response) { '{ "attributeScores": { "SEVERE_TOXICITY": { "spanScores": [ { "begin": 0, "end": 80, "score": { "value": 0.0039000872, "type": "PROBABILITY" } } ], "summaryScore": { "value": 0.0039000872, "type": "PROBABILITY" } } }, "languages": [ "en" ] }' }
    let(:blank) { '' }

    it 'returns toxicity score' do
      response = DiscourseEtiquette.extract_value_from_analyze_comment_response(toxicity_response)
      expect(response[:score]).to be 0.026585817
    end

    it 'returns severe toxicity score' do
      response = DiscourseEtiquette.extract_value_from_analyze_comment_response(severe_toxicity_response)
      expect(response[:score]).to be 0.0039000872
    end

    it 'recovers from attribuets' do
      response = DiscourseEtiquette.extract_value_from_analyze_comment_response(blank)
      expect(response[:score]).to be 0.0
    end
  end

  let(:private_message) { Fabricate(:private_message_post) }
  describe '.should_check_post?' do
    let(:system_message) { Fabricate(:post, user_id: -1) }
    let(:secured_post) { Fabricate(:post) }
    let(:private_category) { Fabricate(:private_category, group: Group.where(name: 'everyone').first) }

    it 'do not check when plugin is not enabled' do
      SiteSetting.etiquette_enabled = false
      expect(DiscourseEtiquette.should_check_post?(post)).to be_falsey
      SiteSetting.etiquette_enabled = true
      expect(DiscourseEtiquette.should_check_post?(post)).to be_truthy
    end

    it 'do not check when post is blank' do
      post.raw = ''
      expect(DiscourseEtiquette.should_check_post?(post)).to be_falsey
    end

    it 'checks private message when allowed' do
      SiteSetting.etiquette_check_private_message = false
      expect(DiscourseEtiquette.should_check_post?(private_message)).to be_falsey
      SiteSetting.etiquette_check_private_message = true
      expect(DiscourseEtiquette.should_check_post?(private_message)).to be_truthy
    end

    it 'skips system message' do
      expect(DiscourseEtiquette.should_check_post?(system_message)).to be_falsey
    end

    it 'skips url post' do
      post.raw = 'https://www.google.com'
      expect(DiscourseEtiquette.should_check_post?(post)).to be_falsey
    end

    it 'skips when in secured category' do
      secured_post.topic.category = private_category
      secured_post.save!
      SiteSetting.etiquette_check_secured_categories = false
      expect(DiscourseEtiquette.should_check_post?(secured_post)).to be_falsey
      SiteSetting.etiquette_check_secured_categories = true
      expect(DiscourseEtiquette.should_check_post?(secured_post)).to be_truthy
    end
  end

  describe '.flag_on_scores' do
    let(:zero_score) { DiscourseEtiquette.extract_value_from_analyze_comment_response(nil) }
    let(:score) { { score: 0.99 } }
    let(:post) { Fabricate(:post) }

    it 'acts if threshold exceeded' do
      PostAction.expects(:act).once
      DiscourseEtiquette.flag_on_scores(score, post)
    end

    it 'does nothing if score is low' do
      PostAction.expects(:act).never
      DiscourseEtiquette.flag_on_scores(zero_score, post)
    end
  end

  context 'requests' do
    let(:user) { Fabricate(:user) }
    let(:post) { Fabricate(:post, user: user) }
    let(:content) { "Hello world" }

    describe 'toxicity check' do
      before do
        stub_request(:post, API_ENDPOINT).to_return(status: 200, body: API_RESPONSE_TOXICITY_BODY, headers: {})
      end

      it '.backfill_post_etiquette_check saves to the post_etiquette_toxicity custom field' do
        DiscourseEtiquette.backfill_post_etiquette_check(post)
        expect(post.custom_fields['post_etiquette_toxicity']).to eq "0.015122943"
      end

      it '.check_post_toxicity returns the score' do
        expect(DiscourseEtiquette.check_post_toxicity(post)).to eq({ score: 0.015122943 })
      end

      it '.check_content_toxicity returns the score if over the threshold' do
        stub_request(:post, API_ENDPOINT).to_return(status: 200, body: API_RESPONSE_HIGH_TOXICITY_BODY, headers: {})
        expect(DiscourseEtiquette.check_content_toxicity(content, user.id)).to eq({ score: 0.915122943 })
      end

      it '.check_content_toxicity returns if below the threshold' do
        expect(DiscourseEtiquette.check_content_toxicity(content, user.id)).to eq nil
      end
    end

    context 'severe toxicity' do
      before do
        stub_request(:post, API_ENDPOINT).to_return(status: 200, body: API_RESPONSE_SEVERE_TOXICITY_BODY, headers: {})
      end

      it 'backfill_post_etiquette_check saves to the post_etiquette_severe_toxicity custom field' do
        SiteSetting.etiquette_toxicity_model = 'severe toxicity (experimental)'
        DiscourseEtiquette.backfill_post_etiquette_check(post)
        expect(post.custom_fields['post_etiquette_severe_toxicity']).to eq "0.0053346273"
      end

      it '.check_post_toxicity returns the score' do
        expect(DiscourseEtiquette.check_post_toxicity(post)).to eq({ score: 0.0053346273 })
      end

      it '.check_content_toxicity returns the score if over the threshold' do
        stub_request(:post, API_ENDPOINT).to_return(status: 200, body: API_RESPONSE_HIGH_SEVERE_TOXICITY_BODY, headers: {})
        expect(DiscourseEtiquette.check_content_toxicity(content, user.id)).to eq({ score: 0.915122943 })
      end

      it '.check_content_toxicity returns if below the threshold' do
        expect(DiscourseEtiquette.check_content_toxicity(content, user.id)).to eq nil
      end
    end
  end
end

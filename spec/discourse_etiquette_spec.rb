require 'rails_helper'

describe DiscourseEtiquette do
  let(:post) { Fabricate(:post) }

  describe 'AnalyzeComment' do
    let(:comment) { DiscourseEtiquette::AnalyzeComment.new(post, post.user_id) }

    it 'generates json' do
      json = MultiJson.load(comment.to_json).deep_symbolize_keys
      expect(json[:comment][:text].blank?).to be_falsey
      expect(json[:requestedAttributes][:TOXICITY][:scoreType].blank?).to be_falsey
    end
  end

  describe '.extract_value_from_analyze_comment_response' do
    let(:response) { '{"attributeScores":{"SEVERE_TOXICITY":{"spanScores":[{"begin":0,"end":31,"score":{"value":0.40343216,"type":"PROBABILITY"}}],"summaryScore":{"value":0.40343216,"type":"PROBABILITY"}},"TOXICITY":{"spanScores":[{"begin":0,"end":31,"score":{"value":0.9064169,"type":"PROBABILITY"}}],"summaryScore":{"value":0.9064169,"type":"PROBABILITY"}}},"languages":["en"]}' }
    let(:blank) { '' }

    it 'returns score hash' do
      score = DiscourseEtiquette.extract_value_from_analyze_comment_response(response)
      expect(score[:severe_toxicity]).to be 0.40343216
      expect(score[:toxicity]).to be 0.9064169
    end

    it 'recovers from attribuets' do
      score = DiscourseEtiquette.extract_value_from_analyze_comment_response(blank)
      expect(score[:severe_toxicity]).to be 0.0
      expect(score[:toxicity]).to be 0.0
    end
  end

  let(:private_message) { Fabricate(:private_message_post) }
  describe '.should_check_post?' do
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

    it 'skips url post' do
      post.raw = 'https://www.google.com'
      expect(DiscourseEtiquette.should_check_post?(post)).to be_falsey
    end
  end
end

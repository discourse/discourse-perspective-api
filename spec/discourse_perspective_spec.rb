# frozen_string_literal: true

require "rails_helper"
require "fakeweb"

API_ENDPOINT = "https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze?key="
API_RESPONSE_TOXICITY_BODY =
  '{"attributeScores": {"TOXICITY": {"spanScores": [{"begin": 0,"end": 11,"score": {"value": 0.015122943,"type": "PROBABILITY"}}],"summaryScore": {"value": 0.015122943,"type": "PROBABILITY"}}},"languages": ["en"]}'
API_RESPONSE_HIGH_TOXICITY_BODY =
  '{"attributeScores": {"TOXICITY": {"spanScores": [{"begin": 0,"end": 11,"score": {"value": 0.915122943,"type": "PROBABILITY"}}],"summaryScore": {"value": 0.915122943,"type": "PROBABILITY"}}},"languages": ["en"]}'
API_RESPONSE_SEVERE_TOXICITY_BODY =
  '{"attributeScores": {"TOXICITY": {"spanScores": [{"begin": 0,"end": 11,"score": {"value": 0.0053346273,"type": "PROBABILITY"}}],"summaryScore": {"value": 0.0053346273,"type": "PROBABILITY"}}},"languages": ["en"]}'
API_RESPONSE_HIGH_SEVERE_TOXICITY_BODY =
  '{"attributeScores": {"TOXICITY": {"spanScores": [{"begin": 0,"end": 11,"score": {"value": 0.915122943,"type": "PROBABILITY"}}],"summaryScore": {"value": 0.915122943,"type": "PROBABILITY"}}},"languages": ["en"]}'

describe DiscoursePerspective do
  before { SiteSetting.perspective_enabled = true }

  let(:post) { Fabricate(:post) }

  describe "AnalyzeComment" do
    let(:json) do
      MultiJson.load(
        DiscoursePerspective::AnalyzeComment.new(post, post.user_id).to_json,
      ).deep_symbolize_keys
    end

    it "generates json" do
      expect(json[:comment][:text].blank?).to be_falsey
      expect(json[:requestedAttributes][:TOXICITY][:scoreType].blank?).to be_falsey
    end

    it "standard perspective_toxicity_model" do
      SiteSetting.perspective_toxicity_model = "standard"
      expect(json[:requestedAttributes][:TOXICITY][:scoreType]).to eq "PROBABILITY"
    end

    it "severe toxicity perspective_toxicity_model" do
      SiteSetting.perspective_toxicity_model = "severe toxicity (experimental)"
      expect(json[:requestedAttributes][:SEVERE_TOXICITY][:scoreType]).to eq "PROBABILITY"
    end
  end

  describe ".unload_json" do
    it "returns an empty dict at least" do
      expect(DiscoursePerspective.unload_json("")).to eq({})
    end
  end

  describe ".extract_value_from_analyze_comment_response" do
    let(:toxicity_response) do
      '{ "attributeScores": { "TOXICITY": { "spanScores": [ { "begin": 0, "end": 80, "score": { "value": 0.026585817, "type": "PROBABILITY" } } ], "summaryScore": { "value": 0.026585817, "type": "PROBABILITY" } } }, "languages": [ "en" ] }'
    end
    let(:severe_toxicity_response) do
      '{ "attributeScores": { "SEVERE_TOXICITY": { "spanScores": [ { "begin": 0, "end": 80, "score": { "value": 0.0039000872, "type": "PROBABILITY" } } ], "summaryScore": { "value": 0.0039000872, "type": "PROBABILITY" } } }, "languages": [ "en" ] }'
      # rubocop:enable Layout/LineLength
    end
    let(:blank) { "" }

    it "returns toxicity score" do
      response = DiscoursePerspective.extract_value_from_analyze_comment_response(toxicity_response)
      expect(response[:score]).to be 0.026585817
    end

    it "returns severe toxicity score" do
      response =
        DiscoursePerspective.extract_value_from_analyze_comment_response(severe_toxicity_response)
      expect(response[:score]).to be 0.0039000872
    end

    it "recovers from attribuets" do
      response = DiscoursePerspective.extract_value_from_analyze_comment_response(blank)
      expect(response[:score]).to be 0.0
    end
  end

  let(:private_message) { Fabricate(:private_message_post) }
  describe ".should_check_post?" do
    let(:system_message) { Fabricate(:post, user_id: -1) }
    let(:secured_post) { Fabricate(:post) }
    let(:private_category) do
      Fabricate(:private_category, group: Group.where(name: "everyone").first)
    end
    let(:deleted_topic) { Fabricate(:deleted_topic) }
    let(:post_in_deleted_topic) { Fabricate(:post, topic: deleted_topic) }

    it "do not check when plugin is not enabled" do
      SiteSetting.perspective_enabled = false
      expect(DiscoursePerspective.should_check_post?(post)).to be_falsey
      SiteSetting.perspective_enabled = true
      expect(DiscoursePerspective.should_check_post?(post)).to be_truthy
    end

    it "do not check when post is blank" do
      post.raw = ""
      expect(DiscoursePerspective.should_check_post?(post)).to be_falsey
    end

    it "checks private message when allowed" do
      SiteSetting.perspective_check_private_message = false
      expect(DiscoursePerspective.should_check_post?(private_message)).to be_falsey
      SiteSetting.perspective_check_private_message = true
      expect(DiscoursePerspective.should_check_post?(private_message)).to be_truthy
    end

    it "skips system message" do
      # TODO weird fabricator should be fixed
      system_message.user_id = -1
      expect(DiscoursePerspective.should_check_post?(system_message)).to be_falsey
    end

    it "skips url post" do
      post.raw = "https://www.google.com"
      expect(DiscoursePerspective.should_check_post?(post)).to be_falsey
    end

    it "skips when in secured category" do
      secured_post.topic.category = private_category
      secured_post.save!
      SiteSetting.perspective_check_secured_categories = false
      expect(DiscoursePerspective.should_check_post?(secured_post)).to be_falsey
      SiteSetting.perspective_check_secured_categories = true
      expect(DiscoursePerspective.should_check_post?(secured_post)).to be_truthy
    end

    it "ignores posts in trashed topic" do
      expect(DiscoursePerspective.should_check_post?(post_in_deleted_topic)).to be_falsey
    end
  end

  describe ".flag_on_scores" do
    let(:zero_score) { DiscoursePerspective.extract_value_from_analyze_comment_response(nil) }
    let(:score) { { score: 0.99 } }
    let(:post) { Fabricate(:post) }

    it "acts if threshold exceeded" do
      PostActionCreator.expects(:create).once
      DiscoursePerspective.flag_on_scores(score, post)
    end

    it "does nothing if score is low" do
      PostActionCreator.expects(:create).never
      DiscoursePerspective.flag_on_scores(zero_score, post)
    end
  end

  describe "requests" do
    let(:user) { Fabricate(:user) }
    let(:post) { Fabricate(:post, user: user) }
    let(:content) { "Hello world" }

    describe "toxicity check" do
      before do
        stub_request(:post, API_ENDPOINT).to_return(
          status: 200,
          body: API_RESPONSE_TOXICITY_BODY,
          headers: {
          },
        )
      end

      it ".backfill_post_perspective_check saves to the post_perspective_toxicity custom field" do
        DiscoursePerspective.backfill_post_perspective_check(post)
        expect(post.custom_fields["post_perspective_toxicity"]).to eq "0.015122943"
      end

      it ".check_post_toxicity returns the score" do
        expect(DiscoursePerspective.check_post_toxicity(post)).to eq(score: 0.015122943)
      end

      it ".check_content_toxicity returns the score if over the threshold" do
        stub_request(:post, API_ENDPOINT).to_return(
          status: 200,
          body: API_RESPONSE_HIGH_TOXICITY_BODY,
          headers: {
          },
        )
        expect(DiscoursePerspective.check_content_toxicity(content, user.id)).to eq(
          score: 0.915122943,
        )
      end

      it ".check_content_toxicity returns if below the threshold" do
        expect(DiscoursePerspective.check_content_toxicity(content, user.id)).to eq nil
      end
    end

    context "with severe toxicity" do
      before do
        stub_request(:post, API_ENDPOINT).to_return(
          status: 200,
          body: API_RESPONSE_SEVERE_TOXICITY_BODY,
          headers: {
          },
        )
      end

      it "backfill_post_perspective_check saves to the post_perspective_severe_toxicity custom field" do
        SiteSetting.perspective_toxicity_model = "severe toxicity (experimental)"
        DiscoursePerspective.backfill_post_perspective_check(post)
        expect(post.custom_fields["post_perspective_severe_toxicity"]).to eq "0.0053346273"
      end

      it ".check_post_toxicity returns the score" do
        expect(DiscoursePerspective.check_post_toxicity(post)).to eq(score: 0.0053346273)
      end

      it ".check_content_toxicity returns the score if over the threshold" do
        stub_request(:post, API_ENDPOINT).to_return(
          status: 200,
          body: API_RESPONSE_HIGH_SEVERE_TOXICITY_BODY,
          headers: {
          },
        )
        expect(DiscoursePerspective.check_content_toxicity(content, user.id)).to eq(
          score: 0.915122943,
        )
      end

      it ".check_content_toxicity returns if below the threshold" do
        expect(DiscoursePerspective.check_content_toxicity(content, user.id)).to eq nil
      end
    end
  end
end

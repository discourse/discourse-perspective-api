# frozen_string_literal: true

require "rails_helper"

describe Jobs::FlagToxicPost do
  describe ".execute" do
    subject(:execute) { described_class.new.execute(args) }

    context "when post_id is missing" do
      let(:args) { {} }

      it "raises an error" do
        expect { execute }.to raise_error(Discourse::InvalidParameters)
      end
    end

    context "when it is given a non existed post" do
      let(:args) { { post_id: 0 } }

      it "returns" do
        expect(execute).to be_nil
      end
    end

    context "with post" do
      let(:post) { Fabricate(:post) }
      let(:args) { { post_id: post.id } }

      context "when the plugin is not enabled" do
        before do
          SiteSetting.perspective_enabled = false
          SiteSetting.perspective_flag_post_min_toxicity_enable = true
        end

        it "returns" do
          expect(execute).to be_nil
        end
      end

      context "when the flag is not enabled" do
        before do
          SiteSetting.perspective_enabled = true
          SiteSetting.perspective_flag_post_min_toxicity_enable = false
        end

        it "returns" do
          expect(execute).to be_nil
        end
      end
    end
  end
end

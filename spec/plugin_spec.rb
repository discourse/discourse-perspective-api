# frozen_string_literal: true

require "rails_helper"

describe DiscoursePerspective do
  before { SiteSetting.perspective_enabled = true }

  describe "when a post is edited" do
    let(:post) { Fabricate(:post) }

    it "queues the post for a toxicity check" do
      expect { PostRevisor.new(post).revise!(post.user, { raw: "updated body" }) }.to change(
        Jobs::FlagToxicPost.jobs,
        :size,
      ).by(1)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

describe Jobs::InspectToxicPost do
  subject(:job) { described_class.new }

  describe "#set_last_checked_post_id" do
    subject(:set_last_checked_post_id) { job.set_last_checked_post_id(0) }

    it "sets value" do
      freeze_time
      set_last_checked_post_id
      expect(PluginStore.get("discourse-perspective", "last_checked_post_id")).to eq 0
      expect(
        PluginStore.get("discourse-perspective", "last_checked_iteration_timestamp"),
      ).to eq DateTime.now.to_s
    end
  end

  describe "#execute" do
    subject(:execute) { job.execute({}) }

    context "when the plugin is not enabled" do
      before do
        SiteSetting.perspective_enabled = false
        SiteSetting.perspective_backfill_posts = true
      end

      it "returns" do
        expect(execute).to be_nil
      end
    end

    context "when the backfill mode is not enabled" do
      before do
        SiteSetting.perspective_enabled = true
        SiteSetting.perspective_backfill_posts = false
      end

      it "returns" do
        expect(execute).to be_nil
      end
    end
  end

  describe "#retry_failed_checks" do
    after { PluginStore.set("discourse-perspective", "failed_post_ids", []) }

    it "retruns while remaining batch size is depleted" do
      expect(job.retry_failed_checks(-1)).to eq nil
    end

    it "checks posts" do
      DiscoursePerspective.stubs(:should_check_post?).returns(true)
      DiscoursePerspective.stubs(:backfill_post_perspective_check).returns(true)

      PluginStore.set("discourse-perspective", "failed_post_ids", [1, 2])
      expect(job.retry_failed_checks(2)).to eq 0
      expect(PluginStore.get("discourse-perspective", "failed_post_ids")).to eq []

      DiscoursePerspective.unstub(:should_check_post?)
      DiscoursePerspective.unstub(:backfill_post_perspective_check)
    end

    it "clears retry list after second attempt is failed" do
      DiscoursePerspective.stubs(:should_check_post?).returns(true)
      DiscoursePerspective.stubs(:backfill_post_perspective_check).raises

      PluginStore.set("discourse-perspective", "failed_post_ids", [1, 2])
      expect(job.retry_failed_checks(2)).to eq 0
      expect(PluginStore.get("discourse-perspective", "failed_post_ids")).to eq []

      DiscoursePerspective.unstub(:should_check_post?)
      DiscoursePerspective.unstub(:backfill_post_perspective_check)
    end
  end

  describe "#check_posts" do
    let!(:post1) { Fabricate(:post) }
    let!(:post2) { Fabricate(:post) }

    after(:each) { PluginStore.set("discourse-perspective", "failed_post_ids", []) }

    it "retruns while remaining batch size is depleted" do
      expect(job.retry_failed_checks(-1)).to eq nil
    end

    it "checks posts" do
      DiscoursePerspective.stubs(:should_check_post?).returns(true)
      DiscoursePerspective.stubs(:backfill_post_perspective_check).returns(true)

      PluginStore.set("discourse-perspective", "last_checked_post_id", 0)
      SiteSetting.perspective_historical_inspection_period = 999_999_999
      job.check_posts(2)
      expect(PluginStore.get("discourse-perspective", "last_checked_post_id")).to eq post2.id

      DiscoursePerspective.unstub(:should_check_post?)
      DiscoursePerspective.unstub(:backfill_post_perspective_check)
    end

    it "stores failed post ids" do
      DiscoursePerspective.stubs(:should_check_post?).returns(true)
      DiscoursePerspective.stubs(:backfill_post_perspective_check).raises

      PluginStore.set("discourse-perspective", "last_checked_post_id", 0)
      SiteSetting.perspective_historical_inspection_period = 999_999_999
      job.check_posts(2)
      expect(PluginStore.get("discourse-perspective", "last_checked_post_id")).to eq post2.id
      PluginStore.set("discourse-perspective", "failed_post_ids", [post1.id, post2.id])
    end
  end

  describe "#start_new_iteration" do
    subject(:start_new_iteration) { job.start_new_iteration }

    it "set values" do
      PluginStore.set("discourse-perspective", "last_checked_post_id", 1)
      start_new_iteration
      expect(PluginStore.get("discourse-perspective", "last_checked_post_id")).to eq 0
    end
  end

  describe "#can_start_next_iteration?" do
    it "doesn't reset when last check is completed not long enough" do
      freeze_time
      PluginStore.set("discourse-perspective", "last_checked_iteration_timestamp", DateTime.now)
      SiteSetting.perspective_historical_inspection_period = 999_999_999
      expect(job.can_start_next_iteration?(99_999_999_999)).to eq false
    end

    it "doesn't reset when the last check is not complete" do
      freeze_time
      PluginStore.set("discourse-perspective", "last_checked_iteration_timestamp", DateTime.now)
      SiteSetting.perspective_historical_inspection_period = 0
      expect(job.can_start_next_iteration?(0)).to eq false
    end

    it "resets when last check is complete and completed long enough" do
      freeze_time
      PluginStore.set("discourse-perspective", "last_checked_iteration_timestamp", DateTime.now)
      SiteSetting.perspective_historical_inspection_period = 0
      expect(job.can_start_next_iteration?(99_999_999_999)).to eq true
    end
  end
end

require 'rails_helper'

describe Jobs::InspectToxicPost do
  describe '.set_last_checked_post_id' do
    it 'sets value' do
      freeze_time
      subject.set_last_checked_post_id(0)
      expect(PluginStore.get('discourse-etiquette', 'last_checked_post_id')).to eq 0
      expect(PluginStore.get('discourse-etiquette', 'last_checked_iteration_timestamp')).to eq DateTime.now.to_s
    end
  end

  context '.execute' do
    it 'returns when the plugin is not enabled' do
      SiteSetting.etiquette_enabled = false
      SiteSetting.etiquette_backfill_posts = true
      expect(subject.execute({})).to eq nil
    end

    it 'returns when the backfill mode is not enabled' do
      SiteSetting.etiquette_enabled = true
      SiteSetting.etiquette_backfill_posts = false
      expect(subject.execute({})).to eq nil
    end
  end

  describe ".retry_failed_checks" do
    after do
      PluginStore.set('discourse-etiquette', 'failed_post_ids', [])
    end

    it 'retruns while remaining batch size is depleted' do
      expect(subject.retry_failed_checks(-1)).to eq nil
    end

    it 'checks posts' do
      DiscourseEtiquette.stubs(:should_check_post?).returns(true)
      DiscourseEtiquette.stubs(:backfill_post_etiquette_check).returns(true)

      PluginStore.set('discourse-etiquette', 'failed_post_ids', [1, 2])
      expect(subject.retry_failed_checks(2)).to eq 0
      expect(PluginStore.get('discourse-etiquette', 'failed_post_ids')).to eq []

      DiscourseEtiquette.unstub(:should_check_post?)
      DiscourseEtiquette.unstub(:backfill_post_etiquette_check)
    end

    it 'clears retry list after second attempt is failed' do
      DiscourseEtiquette.stubs(:should_check_post?).returns(true)
      DiscourseEtiquette.stubs(:backfill_post_etiquette_check).raises

      PluginStore.set('discourse-etiquette', 'failed_post_ids', [1, 2])
      expect(subject.retry_failed_checks(2)).to eq 0
      expect(PluginStore.get('discourse-etiquette', 'failed_post_ids')).to eq []

      DiscourseEtiquette.unstub(:should_check_post?)
      DiscourseEtiquette.unstub(:backfill_post_etiquette_check)
    end
  end

  describe '.check_posts' do
    before(:each) do
      @post1 = Fabricate(:post)
      @post2 = Fabricate(:post)
    end

    after(:each) do
      PluginStore.set('discourse-etiquette', 'failed_post_ids', [])
      Post.delete_all
    end

    it 'retruns while remaining batch size is depleted' do
      expect(subject.retry_failed_checks(-1)).to eq nil
    end

    it 'checks posts' do
      DiscourseEtiquette.stubs(:should_check_post?).returns(true)
      DiscourseEtiquette.stubs(:backfill_post_etiquette_check).returns(true)

      PluginStore.set('discourse-etiquette', 'last_checked_post_id', 0)
      SiteSetting.etiquette_historical_inspection_period = 999999999
      subject.check_posts(2)
      expect(PluginStore.get('discourse-etiquette', 'last_checked_post_id')).to eq @post2.id

      DiscourseEtiquette.unstub(:should_check_post?)
      DiscourseEtiquette.unstub(:backfill_post_etiquette_check)
    end

    it 'stores failed post ids' do
      DiscourseEtiquette.stubs(:should_check_post?).returns(true)
      DiscourseEtiquette.stubs(:backfill_post_etiquette_check).raises

      PluginStore.set('discourse-etiquette', 'last_checked_post_id', 0)
      SiteSetting.etiquette_historical_inspection_period = 999999999
      subject.check_posts(2)
      expect(PluginStore.get('discourse-etiquette', 'last_checked_post_id')).to eq @post2.id
      PluginStore.set('discourse-etiquette', 'failed_post_ids', [@post1.id, @post2.id])
    end
  end

  describe '.start_new_iteration' do
    it 'set values' do
      PluginStore.set('discourse-etiquette', 'last_checked_post_id', 1)
      subject.start_new_iteration
      expect(PluginStore.get('discourse-etiquette', 'last_checked_post_id')).to eq 0
    end
  end

  describe '.can_start_next_iteration?' do
    it "doesn't reset when last check is completed not long enough" do
      freeze_time
      PluginStore.set('discourse-etiquette', 'last_checked_iteration_timestamp', DateTime.now)
      SiteSetting.etiquette_historical_inspection_period = 999999999
      expect(subject.can_start_next_iteration?(99999999999)).to eq false
    end

    it "doesn't reset when the last check is not complete" do
      freeze_time
      PluginStore.set('discourse-etiquette', 'last_checked_iteration_timestamp', DateTime.now)
      SiteSetting.etiquette_historical_inspection_period = 0
      expect(subject.can_start_next_iteration?(0)).to eq false
    end

    it "resets when last check is complete and completed long enough" do
      freeze_time
      PluginStore.set('discourse-etiquette', 'last_checked_iteration_timestamp', DateTime.now)
      SiteSetting.etiquette_historical_inspection_period = 0
      expect(subject.can_start_next_iteration?(99999999999)).to eq true
    end
  end
end

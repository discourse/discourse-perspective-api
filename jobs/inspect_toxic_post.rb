# frozen_string_literal: true

module Jobs
  class InspectToxicPost < ::Jobs::Scheduled
    every 10.minutes

    BATCH_SIZE = 1000
    LAST_CHECKED_POST_ID_KEY = "last_checked_post_id"
    LAST_CHECKED_TIME_KEY = "last_checked_iteration_timestamp"
    FAILED_POST_ID_KEY = "failed_post_ids"

    def store
      @store ||= PluginStore.new("discourse-perspective")
    end

    def set_last_checked_post_id(val)
      val = val.to_i
      store.set(LAST_CHECKED_TIME_KEY, DateTime.now)
      store.set(LAST_CHECKED_POST_ID_KEY, val)
    end

    def execute(args)
      return unless SiteSetting.perspective_enabled? && SiteSetting.perspective_backfill_posts

      batch_size = retry_failed_checks(BATCH_SIZE)
      check_posts(batch_size)
    end

    def retry_failed_checks(batch_size)
      return if batch_size <= 0
      failed_post_ids = store.get(FAILED_POST_ID_KEY) || []

      queued_post = failed_post_ids[0...batch_size]
      unless queued_post.empty?
        queued_post.each do |post_id|
          post = Post.includes(:topic).find_by(id: post_id)
          next unless post

          if DiscoursePerspective.should_check_post?(post)
            begin
              DiscoursePerspective.backfill_post_perspective_check(post)
            rescue => error
              Rails.logger.warn(error)
              next
            end
          end
        end
      end
      store.set(FAILED_POST_ID_KEY, failed_post_ids[batch_size..-1].to_a)
      batch_size - queued_post.size
    end

    def check_posts(batch_size)
      return if batch_size <= 0
      queued = Set.new
      checked = Set.new
      last_checked_post_id = store.get(LAST_CHECKED_POST_ID_KEY).to_i
      last_id = last_checked_post_id
      Post
        .includes(:topic)
        .offset(last_checked_post_id)
        .limit(batch_size)
        .find_each do |p|
          queued.add(p.id)
          last_id = p.id
          if DiscoursePerspective.should_check_post?(p)
            begin
              DiscoursePerspective.backfill_post_perspective_check(p)
              checked.add(p.id)
            rescue => error
              Rails.logger.info(error)
              next
            end
          end
        end

      set_last_checked_post_id(last_id)
      failed_post_ids = (queued - checked)
      unless failed_post_ids.empty?
        failed_post_ids = failed_post_ids + Set.new(store.get(FAILED_POST_ID_KEY))
        store.set(FAILED_POST_ID_KEY, failed_post_ids.to_a)
      end

      start_new_iteration if can_start_next_iteration?(last_id)
    end

    def can_start_next_iteration?(last_id)
      last_checked_post_timestamp = store.get(LAST_CHECKED_TIME_KEY)&.to_datetime || 100.years.ago
      last_post_id = Post.order(id: :asc).pluck(:id).last || 1
      DateTime.now >=
        last_checked_post_timestamp + SiteSetting.perspective_historical_inspection_period &&
        last_id >= last_post_id
    end

    def start_new_iteration
      set_last_checked_post_id(0)
    end
  end
end

# frozen_string_literal: true

module Jobs
  class FlagToxicPost < ::Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:post_id) if args[:post_id].blank?

      unless SiteSetting.perspective_enabled? &&
               SiteSetting.perspective_flag_post_min_toxicity_enable?
        return
      end

      post = Post.where(id: args[:post_id]).first
      return if post.blank? || post.trashed?

      DiscoursePerspective.check_post_toxicity(post)
    end
  end
end

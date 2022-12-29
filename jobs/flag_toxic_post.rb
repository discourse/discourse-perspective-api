# frozen_string_literal: true

module Jobs
  class FlagToxicPost < ::Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:post_id) unless args[:post_id].present?

      unless SiteSetting.perspective_enabled? &&
               SiteSetting.perspective_flag_post_min_toxicity_enable?
        return
      end

      post = Post.where(id: args[:post_id]).first
      return unless post.present? && !post.trashed?

      DiscoursePerspective.check_post_toxicity(post)
    end
  end
end

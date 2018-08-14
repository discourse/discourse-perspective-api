module Jobs
  class FlagToxicPost < Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:post_id) unless args[:post_id].present?

      return unless SiteSetting.etiquette_enabled? && SiteSetting.etiquette_flag_post_min_toxicity_enable?

      post = Post.where(id: args[:post_id]).first
      return unless post.present? && !post.trashed?

      DiscourseEtiquette.check_post_toxicity(post)
    end
  end
end

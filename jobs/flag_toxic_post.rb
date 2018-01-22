module Jobs
  class FlagToxicPost < Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:post_id) unless args[:post_id].present?

      return unless SiteSetting.etiquett_enabled?

      post = Post.with_deleted.where(id: args[:post_id]).first
      return unless post.present?

      DiscourseEtiquette.check_post_toxicity(post)
    end
  end
end

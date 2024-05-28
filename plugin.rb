# frozen_string_literal: true

# name: discourse-perspective-api
# about: Mark uncivil posts using Google's Perspective API
# meta_topic_id: 98733
# version: 1.2
# authors: Erick Guan
# url: https://github.com/discourse/discourse-perspective-api

enabled_site_setting :perspective_enabled

require "excon"

require_relative "lib/discourse_perspective"

after_initialize do
  module ::DiscoursePerspectiveApi
    PLUGIN_NAME = "discourse-perspective-api"
  end

  require_relative "jobs/flag_toxic_post"
  require_relative "jobs/inspect_toxic_post"

  on(:post_created) do |post, params|
    if SiteSetting.perspective_flag_post_min_toxicity_enable? &&
         DiscoursePerspective.should_check_post?(post)
      Jobs.enqueue(:flag_toxic_post, post_id: post.id)
    end
  end

  on(:post_edited) do |post|
    if SiteSetting.perspective_flag_post_min_toxicity_enable? &&
         DiscoursePerspective.should_check_post?(post)
      Jobs.enqueue(:flag_toxic_post, post_id: post.id)
    end
  end

  require_dependency "application_controller"

  module ::Perspective
    class PostToxicityController < ::ApplicationController
      requires_plugin DiscoursePerspectiveApi::PLUGIN_NAME

      def post_toxicity
        if current_user
          RateLimiter.new(current_user, "post-toxicity", 8, 1.minute).performed!
        else
          RateLimiter.new(nil, "post-toxicity-#{request.remote_ip}", 6, 1.minute).performed!
        end

        hijack do
          begin
            if scores = check_content(params[:concat])
              render json: scores
            else
              render json: {}
            end
          rescue => e
            render json: { errors: [e.message] }, status: 403
          end
        end
      end

      private

      def check_content(content)
        content.present? && DiscoursePerspective.check_content_toxicity(content, current_user)
      end
    end

    class Engine < ::Rails::Engine
      engine_name DiscoursePerspectiveApi::PLUGIN_NAME
      isolate_namespace Perspective
    end
  end

  Perspective::Engine.routes.draw { post "post_toxicity" => "post_toxicity#post_toxicity" }

  Discourse::Application.routes.append { mount ::Perspective::Engine, at: "/perspective" }
end

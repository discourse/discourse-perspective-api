# name: discourse-etiquette
# about: Mark uncivil posts by Google's Perspective API
# version: 1.1
# authors: Erick Guan
# url: https://github.com/fantasticfears/discourse-etiquette

enabled_site_setting :etiquette_enabled

require 'excon'

load File.expand_path('../lib/discourse_etiquette.rb', __FILE__)

PLUGIN_NAME ||= "discourse-etiquette".freeze

after_initialize do
  load File.expand_path('../jobs/flag_toxic_post.rb', __FILE__)
  load File.expand_path('../jobs/inspect_toxic_post.rb', __FILE__)

  on(:post_created) do |post, params|
    if DiscourseEtiquette.should_check_post?(post)
      Jobs.enqueue(:flag_toxic_post, post_id: post.id)
    end
  end

  register_post_custom_field_type(DiscourseEtiquette.post_score_field_name, :float)

  require_dependency "application_controller"

  module ::Etiquette
    class PostToxicityController < ::ApplicationController
      requires_plugin PLUGIN_NAME

      def show
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
        content&.present? && DiscourseEtiquette.check_content_toxicity(content, current_user)
      end
    end

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace Etiquette
    end
  end

  Etiquette::Engine.routes.draw do
    get 'post_toxicity' => 'post_toxicity#show'
  end

  Discourse::Application.routes.append do
    mount ::Etiquette::Engine, at: '/etiquette'
  end

end

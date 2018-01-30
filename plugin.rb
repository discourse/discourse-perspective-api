# name: discourse-etiquette
# about: Mark uncivil posts by Google's Perspective API
# version: 1.0
# authors: Erick Guan
# url: https://github.com/fantasticfears/discourse-etiquette

enabled_site_setting :etiquette_enabled

require 'excon'

load File.expand_path('../lib/discourse_etiquette.rb', __FILE__)

PLUGIN_NAME ||= "discourse-etiquette".freeze

after_initialize do
  require_dependency File.expand_path('../jobs/flag_toxic_post.rb', __FILE__)

  on(:post_created) do |post, params|
    if DiscourseEtiquette.should_check_post?(post)
      Jobs.enqueue(:flag_toxic_post, post_id: post.id)
    end
  end

  require_dependency "application_controller"

  module ::Etiquette
    class EtiquetteMessagesController < ::ApplicationController
      requires_plugin PLUGIN_NAME
      rescue_from DiscourseEtiquette::NetworkError do |err|
        render :nothing, status: 422
      end

      def show
        # TODO: rate limit?
        if scores = check_content(params[:concat])
          render json: scores
        else
          render :nothing, status: 422
        end
      end

      private

      def check_content(content)
        !content.empty? && DiscourseEtiquette.check_content_toxicity(content, current_user)
      end
    end

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace Etiquette
    end
  end

  Etiquette::Engine.routes.draw do
    get 'etiquette_messages' => 'etiquette_messages#show'
  end

  Discourse::Application.routes.append do
    mount ::Etiquette::Engine, at: '/'
  end

end

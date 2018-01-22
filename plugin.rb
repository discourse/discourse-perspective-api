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

  module ::Etiquette
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      # isolate_namespace Etiquette
    end
  end

  on(:post_created) do |post, params|
    if DiscourseEtiquette.should_check_post?(post)
      Jobs.enqueue(:flag_toxic_post, post_id: post.id)
    end
  end

  # require_dependency "application_controller"

  # class Etiquette::Controller < ::ApplicationController
  #   requires_plugin PLUGIN_NAME
  #   before_action :ensure_logged_in


  # Presence::Engine.routes.draw do
  # end

  # Discourse::Application.routes.append do
  #   mount ::Etiquette::Engine, at: '/etiquette'
  # end

end

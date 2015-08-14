module DefaultActions
  class Engine < ::Rails::Engine
    isolate_namespace DefaultActions
  end
end

require 'default_actions/controller'
require 'default_actions/index_view'
require 'default_actions/show_view'

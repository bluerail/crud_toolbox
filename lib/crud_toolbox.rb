require 'rails'

I18n.load_path += Dir["#{File.dirname(__FILE__)}/../config/locales/*.yml"]

module CrudToolbox
  class Engine < ::Rails::Engine
    isolate_namespace CrudToolbox
    config.crud_toolbox = CrudToolbox
  end

  mattr_accessor :use_gettext
  @@use_gettext = !!defined?(_)

  mattr_accessor :use_form_this
  @@use_form_this = !!defined?(FormThis)

  mattr_accessor :use_pundit
  @@use_pundit = !!defined?(Pundit)

end

require 'crud_toolbox/controller'
require 'crud_toolbox/list_view'
require 'crud_toolbox/show_view'

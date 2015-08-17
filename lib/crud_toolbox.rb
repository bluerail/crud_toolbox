module CrudToolbox
  class Engine < ::Rails::Engine
    isolate_namespace CrudToolbox
  end
end

require 'crud_toolbox/controller'
require 'crud_toolbox/index_view'
require 'crud_toolbox/show_view'
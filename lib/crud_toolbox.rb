module CrudToolbox
  class Engine < ::Rails::Engine
    isolate_namespace CrudToolbox
  end
end

require 'crud_toolbox/column'
require 'crud_toolbox/controller'
require 'crud_toolbox/list_view/base'
require 'crud_toolbox/show_view/base'

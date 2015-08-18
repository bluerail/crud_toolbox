$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name = 'crud_toolbox'
  s.version = '0.1'
  s.authors = ["Martin Tournoij"]
  s.email = ["martin@lico.nl"]
  s.homepage = 'https://github.com/bluerail/'
  s.summary = 'Easy CRUD'
  s.description = 'Easy CRUD for Rails'
  s.license = "MIT"

  s.files = Dir["{app,lib}/**/*", "MIT-LICENSE"]
  #s.test_files = Dir["test/**/*"]

  s.add_dependency 'rails'
  s.add_dependency 'kaminari'
  s.add_dependency 'pundit'
  s.add_dependency 'jquery-rails'
  s.add_dependency 'sugar-rails'

  s.add_development_dependency "sqlite3"
end

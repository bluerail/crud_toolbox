$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name = "default_actions"
  s.version = '0.1'
  s.authors = ["Martin Tournoij"]
  s.email = ["martin@lico.nl"]
  s.homepage = 'https://github.com/bluerail/'
  s.summary = 'Easy CRUD'
  s.description = 'Easy CRUD for Rails'
  s.license = "MIT"

  s.files = Dir["{app,lib}/**/*", "MIT-LICENSE"]
  #s.test_files = Dir["test/**/*"]

  s.add_dependency 'rails', '~> 4.2.0'
  s.add_dependency 'kaminari', '~> 0.16.0'
  s.add_dependency 'pundit', '~> 0.3.0'
  s.add_dependency 'jquery-rails', '~> 4.0.0'

  s.add_development_dependency "sqlite3"
end

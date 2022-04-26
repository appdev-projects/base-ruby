require 'bundler/setup'
require "web_git"

<<<<<<< HEAD
=======
map '/' do
  dir = Gem::Specification.find_by_name('web_git').gem_dir
  path = dir + '/lib/views/index.html'
  default_homepage = File.read(path)
  app = proc do |env|
    [200, { 'Content-Type' => 'text/html' }, [default_homepage]]
  end
  run app
end

>>>>>>> da21993... Updates
map '/git' do
  run WebGit::Server
end

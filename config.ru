$LOAD_PATH << File.dirname(__FILE__)

require 'redline'

config = File.exist?('settings.yml') ? YAML.load_file('settings.yml') : {}
use Redline::Application, config
run Sinatra::Application

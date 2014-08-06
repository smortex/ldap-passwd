require 'active_support/core_ext/hash/indifferent_access'
require 'yaml'

require File.expand_path('../application.rb', __FILE__)
require File.expand_path('../lib/secret.rb', __FILE__)
require File.expand_path('../lib/sms.rb', __FILE__)

$config = HashWithIndifferentAccess.new(YAML.load_file(File.expand_path('../config.yml', __FILE__))[ENV['RACK_ENV'] || 'development'])

run Application

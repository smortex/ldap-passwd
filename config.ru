# frozen_string_literal: true

require 'active_support/core_ext/hash/indifferent_access'
require 'yaml'

require File.expand_path('application.rb', __dir__)
require File.expand_path('lib/secret.rb', __dir__)

$doc = nil
$config = HashWithIndifferentAccess.new(YAML.load_file(File.expand_path('config.yml',
                                                                        __dir__))[ENV['RACK_ENV'] || 'development'])

run Application

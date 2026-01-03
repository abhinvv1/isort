#!/usr/bin/env ruby
# frozen_string_literal: true

# This is a test file to verify isort works on real-world Ruby code

require "json"
require "optparse"
require "yaml"

require_relative "config/database"
require_relative "lib/helpers"

include Comparable

extend ActiveSupport::Concern

autoload :Logger, "logger"

using RefinedString
class Application
  include Enumerable

  extend ClassMethods

  def initialize
    @config = load_config
  end

  private

  def load_config
    YAML.load_file("config.yml")
  end
end

Application.new if __FILE__ == $PROGRAM_NAME

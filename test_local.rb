#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick script to test isort locally
# Usage: bundle exec ruby test_local.rb

$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "isort"
require "tempfile"

puts "=" * 60
puts "Testing isort locally"
puts "=" * 60

# Create a test file with unsorted imports
test_content = <<~RUBY
  require 'yaml'
  require_relative 'helper'
  require 'json'
  include Enumerable
  require 'csv'
  extend ActiveSupport::Concern
  require_relative 'version'

  class MyApp
    def run
      puts "Hello"
    end
  end
RUBY

tempfile = Tempfile.new(["test_isort", ".rb"])
tempfile.write(test_content)
tempfile.flush

puts "\n📄 Original file:"
puts "-" * 40
puts test_content

puts "\n🔍 Running --check mode:"
puts "-" * 40
processor = Isort::FileProcessor.new(tempfile.path)
would_change = processor.check
puts would_change ? "File needs sorting" : "File is already sorted"

puts "\n📝 Running --diff mode:"
puts "-" * 40
diff_output = processor.diff
if diff_output
  puts diff_output
else
  puts "No changes needed"
end

puts "\n✅ Running sort:"
puts "-" * 40
processor2 = Isort::FileProcessor.new(tempfile.path)
changed = processor2.process

puts "\n📄 Sorted file:"
puts "-" * 40
puts File.read(tempfile.path)

puts "\n🔄 Testing idempotency (running again):"
puts "-" * 40
processor3 = Isort::FileProcessor.new(tempfile.path)
changed_again = processor3.process
puts changed_again ? "File changed (NOT idempotent!)" : "No changes (idempotent ✓)"

# Test skip directive
puts "\n🚫 Testing skip directive:"
puts "-" * 40
skip_content = <<~RUBY
  require 'yaml' # isort:skip
  require 'json'
  require 'csv'
RUBY

tempfile2 = Tempfile.new(["test_skip", ".rb"])
tempfile2.write(skip_content)
tempfile2.flush

puts "Original:"
puts skip_content
Isort::FileProcessor.new(tempfile2.path).process
puts "\nAfter sorting (yaml should stay first due to skip):"
puts File.read(tempfile2.path)

# Test section-based grouping
puts "\n📦 Section-based grouping:"
puts "-" * 40
puts "Imports are grouped by section:"
puts "  1. stdlib (json, csv, yaml...)"
puts "  2. thirdparty (rails, active_support...)"
puts "  3. firstparty (include, extend, autoload, using)"
puts "  4. localfolder (require_relative)"

# Cleanup
tempfile.close
tempfile.unlink
tempfile2.close
tempfile2.unlink

puts "\n" + "=" * 60
puts "All tests completed!"
puts "=" * 60

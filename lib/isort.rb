# frozen_string_literal: true

require "optparse"

require_relative "isort/version"
require_relative "isort/parser"
require_relative "isort/import_statement"
require_relative "isort/import_block"
require_relative "isort/file_processor"
require_relative "isort/syntax_validator"
require_relative "isort/wrap_modes"

module Isort
  class Error < StandardError; end

  # Raised when the input file already has syntax errors
  class ExistingSyntaxErrors < Error
    def initialize(file_path)
      super("#{file_path} has existing syntax errors - skipping")
    end
  end

  # Raised when isort would introduce syntax errors
  class IntroducedSyntaxErrors < Error
    def initialize(file_path)
      super("isort would introduce syntax errors in #{file_path} - not saving")
    end
  end

  # Raised when file contains skip directive
  class FileSkipped < Error
    def initialize(file_path, reason = "skip directive")
      super("#{file_path} skipped due to #{reason}")
    end
  end

  # FileSorter provides the public API for sorting imports in a Ruby file
  class FileSorter
    attr_reader :file_path

    def initialize(file_path, options = {})
      @file_path = file_path
      @options = {
        check: false,
        diff: false,
        atomic: false,
        quiet: false
      }.merge(options)
      @processor = FileProcessor.new(file_path, @options)
    end

    # Sort and format imports in the file
    # Returns true if changes were made (or would be made in check mode)
    def sort_and_format_imports
      @processor.process
    rescue Errno::ENOENT
      raise
    rescue ExistingSyntaxErrors, IntroducedSyntaxErrors, FileSkipped
      raise
    rescue StandardError => e
      puts "An error occurred: #{e.message}" unless @options[:quiet]
      raise
    end

    # Check if file would change (dry-run)
    def check
      @processor.check
    end

    # Get diff of changes without applying
    def diff
      @processor.diff
    end

    # Legacy method for backward compatibility
    # @deprecated Use sort_and_format_imports instead
    def sort_imports
      sort_and_format_imports
    end
  end

  # CLI handles command-line interface for the isort gem
  class CLI
    def self.start
      options = {
        check: false,
        diff: false,
        atomic: false,
        quiet: false,
        verbose: false
      }

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: isort [options] [file_or_directory]"
        opts.separator ""
        opts.separator "Options:"

        opts.on("-f", "--file=FILE", "File to sort") do |file|
          options[:file] = file
        end

        opts.on("-d", "--directory=DIRECTORY", "Directory to sort (recursive)") do |dir|
          options[:directory] = dir
        end

        opts.separator ""
        opts.separator "Safety options:"

        opts.on("-c", "--check", "--check-only",
                "Check if files need sorting without modifying them.",
                "Returns exit code 0 if sorted, 1 if changes needed.") do
          options[:check] = true
        end

        opts.on("--diff", "Show diff of changes without modifying files.") do
          options[:diff] = true
        end

        opts.on("--atomic", "Validate Ruby syntax before and after sorting.",
                "Won't save if it would introduce syntax errors.") do
          options[:atomic] = true
        end

        opts.separator ""
        opts.separator "Output options:"

        opts.on("-q", "--quiet", "Suppress all output except errors.") do
          options[:quiet] = true
        end

        opts.on("--verbose", "Show detailed output.") do
          options[:verbose] = true
        end

        opts.separator ""
        opts.separator "Information:"

        opts.on("-h", "--help", "Show this help message.") do
          puts opts
          exit
        end

        opts.on("-v", "--version", "Show version.") do
          puts "isort #{Isort::VERSION}"
          exit
        end
      end

      # Parse arguments
      parser.parse!

      # Handle positional arguments
      if ARGV.any? && !options[:file] && !options[:directory]
        target = ARGV.first
        if File.directory?(target)
          options[:directory] = target
        elsif File.file?(target)
          options[:file] = target
        else
          puts "Error: #{target} is not a valid file or directory"
          exit 1
        end
      end

      if options[:file]
        exit_code = process_file(options[:file], options)
        exit exit_code
      elsif options[:directory]
        exit_code = process_directory(options[:directory], options)
        exit exit_code
      else
        puts parser
        exit 1
      end
    end

    def self.process_file(file, options)
      unless File.exist?(file)
        puts "Error: File not found: #{file}" unless options[:quiet]
        return 1
      end

      processor = FileProcessor.new(file, options)

      if options[:check]
        handle_check(file, processor, options)
      elsif options[:diff]
        handle_diff(file, processor, options)
      else
        handle_sort(file, processor, options)
      end
    rescue ExistingSyntaxErrors => e
      puts "ERROR: #{e.message}" unless options[:quiet]
      1
    rescue IntroducedSyntaxErrors => e
      puts "ERROR: #{e.message}" unless options[:quiet]
      1
    rescue FileSkipped => e
      puts e.message if options[:verbose]
      0
    rescue StandardError => e
      puts "Error processing #{file}: #{e.message}" unless options[:quiet]
      1
    end

    def self.handle_check(file, processor, options)
      would_change = processor.check
      if would_change
        puts "#{file} - imports are not sorted" unless options[:quiet]
        1
      else
        puts "#{file} - imports are sorted" if options[:verbose]
        0
      end
    end

    def self.handle_diff(file, processor, options)
      diff_output = processor.diff
      if diff_output && !diff_output.empty?
        puts diff_output
        1
      else
        puts "#{file} - no changes" if options[:verbose]
        0
      end
    end

    def self.handle_sort(file, processor, options)
      changed = processor.process
      if changed
        puts "Imports sorted in #{file}" unless options[:quiet]
      elsif options[:verbose]
        puts "#{file} - no changes needed"
      end
      0
    end

    def self.process_directory(dir, options)
      unless Dir.exist?(dir)
        puts "Error: Directory not found: #{dir}" unless options[:quiet]
        return 1
      end

      files = Dir.glob("#{dir}/**/*.rb")
      if files.empty?
        puts "No Ruby files found in #{dir}" unless options[:quiet]
        return 0
      end

      total = 0
      changed = 0
      errors = 0
      error_messages = []

      files.each do |file|
        result = process_file(file, options.merge(quiet: true))
        total += 1
        if result.zero?
          changed += 1 if options[:check] || options[:diff]
        else
          errors += 1
        end
      rescue StandardError => e
        errors += 1
        error_messages << "#{file}: #{e.message}"
      end

      unless options[:quiet]
        if options[:check]
          unsorted = total - changed
          puts "Checked #{total} files: #{changed} sorted, #{unsorted} need sorting"
        elsif options[:diff]
          puts "Checked #{total} files: #{total - changed} would change"
        else
          puts "Sorted imports in #{total} files in directory: #{dir}"
        end

        if error_messages.any?
          puts "\nErrors encountered:"
          error_messages.each { |err| puts "  - #{err}" }
        end
      end

      errors.positive? || (options[:check] && changed < total) ? 1 : 0
    end
  end
end

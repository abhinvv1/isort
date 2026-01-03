# frozen_string_literal: true

module Isort
  # Validates Ruby syntax using the built-in parser
  # Used by --atomic mode to ensure sorting doesn't introduce syntax errors
  class SyntaxValidator
    class << self
      # Check if Ruby code has valid syntax
      # Returns true if valid, false otherwise
      def valid?(code)
        check_syntax(code).nil?
      end

      # Check syntax and return error message if invalid, nil if valid
      def check_syntax(code)
        # Use Ruby's built-in syntax check
        catch(:valid) do
          eval("BEGIN { throw :valid }; #{code}", nil, __FILE__, __LINE__)
        end
        nil
      rescue SyntaxError => e
        e.message
      rescue StandardError
        # Other errors during eval don't indicate syntax errors
        nil
      end

      # Check if a file has valid Ruby syntax
      def valid_file?(file_path)
        return false unless File.exist?(file_path)

        content = File.read(file_path, encoding: "UTF-8")
        valid?(content)
      rescue Errno::ENOENT, Encoding::InvalidByteSequenceError
        false
      end

      # Use Ruby's built-in -c flag for more accurate syntax checking
      # This is safer than eval-based checking
      def valid_with_ruby_c?(code)
        require "open3"
        require "tempfile"

        Tempfile.create(["syntax_check", ".rb"]) do |f|
          f.write(code)
          f.flush

          _, _, status = Open3.capture3("ruby", "-c", f.path)
          status.success?
        end
      rescue StandardError
        # If we can't run ruby -c, fall back to eval-based check
        valid?(code)
      end

      # Check syntax using ruby -c (more reliable but slower)
      # Returns nil if valid, error message if invalid
      def check_syntax_with_ruby_c(code)
        require "open3"
        require "tempfile"

        Tempfile.create(["syntax_check", ".rb"]) do |f|
          f.write(code)
          f.flush

          _, stderr, status = Open3.capture3("ruby", "-c", f.path)
          status.success? ? nil : stderr.strip
        end
      rescue StandardError
        # If we can't run ruby -c, fall back to eval-based check
        check_syntax(code)
      end
    end
  end
end

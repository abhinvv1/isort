# frozen_string_literal: true

require "set"

module Isort
  # Categorizes imports into sections based on their source
  # - STDLIB: Ruby standard library
  # - THIRDPARTY: Gems/external packages
  # - FIRSTPARTY: Project's own modules
  # - LOCALFOLDER: Relative imports
  class Section
    SECTIONS = %i[stdlib thirdparty firstparty localfolder].freeze

    SECTION_ORDER = {
      stdlib: 0,
      thirdparty: 1,
      firstparty: 2,
      localfolder: 3
    }.freeze

    # Ruby standard library modules (partial list of common ones)
    # This list covers the most commonly used stdlib modules
    STDLIB_MODULES = Set.new(%w[
                               abbrev
                               base64
                               benchmark
                               bigdecimal
                               cgi
                               csv
                               date
                               delegate
                               digest
                               drb
                               english
                               erb
                               etc
                               fcntl
                               fiddle
                               fileutils
                               find
                               forwardable
                               getoptlong
                               io/console
                               io/nonblock
                               io/wait
                               ipaddr
                               irb
                               json
                               logger
                               matrix
                               minitest
                               monitor
                               mutex_m
                               net/ftp
                               net/http
                               net/https
                               net/imap
                               net/pop
                               net/smtp
                               nkf
                               objspace
                               observer
                               open-uri
                               open3
                               openssl
                               optparse
                               ostruct
                               pathname
                               pp
                               prettyprint
                               prime
                               pstore
                               psych
                               racc
                               rake
                               rdoc
                               readline
                               resolv
                               ripper
                               rss
                               securerandom
                               set
                               shellwords
                               singleton
                               socket
                               stringio
                               strscan
                               syslog
                               tempfile
                               time
                               timeout
                               tmpdir
                               tracer
                               tsort
                               un
                               uri
                               weakref
                               webrick
                               yaml
                               zlib
                             ]).freeze

    class << self
      # Classify an import statement into a section
      def classify(statement)
        case statement.type
        when :require
          classify_require(statement)
        when :require_relative
          :localfolder
        when :include, :extend, :using
          classify_module(statement)
        when :autoload
          :firstparty # autoload is typically project-specific
        else
          :thirdparty
        end
      end

      # Get the section order for sorting
      def order(section)
        SECTION_ORDER[section] || 999
      end

      private

      def classify_require(statement)
        # Extract the require path
        stripped = statement.raw_line.strip
        path = nil

        if (match = stripped.match(/^require\s+['"]([^'"]+)['"]/))
          path = match[1]
        elsif (match = stripped.match(/^require\(['"]([^'"]+)['"]\)/))
          path = match[1]
        end

        return :thirdparty unless path

        # Check if it's a stdlib module
        if stdlib_module?(path)
          :stdlib
        else
          :thirdparty
        end
      end

      def classify_module(statement)
        # Include, extend, using are typically project-specific
        # unless they're from well-known gems
        stripped = statement.raw_line.strip

        # Extract module name
        module_name = nil
        if (match = stripped.match(/^(?:include|extend|using)\s+(\S+)/))
          module_name = match[1]
        end

        return :firstparty unless module_name

        # Check for known stdlib modules
        if stdlib_constant?(module_name)
          :stdlib
        else
          :firstparty
        end
      end

      def stdlib_module?(path)
        # Remove file extension if present
        base_path = path.sub(/\.rb$/, "")

        # Check direct match
        return true if STDLIB_MODULES.include?(base_path)

        # Check prefix (e.g., 'net/http' for 'net/http/response')
        STDLIB_MODULES.any? do |mod|
          base_path.start_with?("#{mod}/") || base_path == mod
        end
      end

      def stdlib_constant?(name)
        # Common Ruby stdlib constants
        stdlib_constants = %w[
          Comparable
          Enumerable
          Forwardable
          Observable
          Singleton
          MonitorMixin
          Mutex_m
        ]
        stdlib_constants.any? { |c| name.start_with?(c) }
      end
    end
  end
end

# frozen_string_literal: true

require "isort"

RSpec.describe Isort::Parser do
  let(:parser) { described_class.new }

  describe "#classify_line" do
    context "with import statements" do
      it "classifies require statements" do
        expect(parser.classify_line("require 'json'")).to eq(:require)
        expect(parser.classify_line('require "json"')).to eq(:require)
        expect(parser.classify_line("require('json')")).to eq(:require)
      end

      it "classifies require_relative statements" do
        expect(parser.classify_line("require_relative 'helper'")).to eq(:require_relative)
        expect(parser.classify_line('require_relative "helper"')).to eq(:require_relative)
        expect(parser.classify_line("require_relative('helper')")).to eq(:require_relative)
      end

      it "classifies include statements" do
        expect(parser.classify_line("include Enumerable")).to eq(:include)
        expect(parser.classify_line("include(Enumerable)")).to eq(:include)
      end

      it "classifies extend statements" do
        expect(parser.classify_line("extend ActiveSupport::Concern")).to eq(:extend)
        expect(parser.classify_line("extend(ActiveSupport::Concern)")).to eq(:extend)
      end

      it "classifies autoload statements" do
        expect(parser.classify_line("autoload :Foo, 'foo'")).to eq(:autoload)
        expect(parser.classify_line("autoload(:Foo, 'foo')")).to eq(:autoload)
      end

      it "classifies using statements" do
        expect(parser.classify_line("using MyRefinement")).to eq(:using)
        expect(parser.classify_line("using(MyRefinement)")).to eq(:using)
      end
    end

    context "with comments" do
      it "classifies regular comments" do
        expect(parser.classify_line("# This is a comment")).to eq(:comment)
      end

      it "classifies shebang on first line" do
        expect(parser.classify_line("#!/usr/bin/env ruby", line_number: 1)).to eq(:shebang)
      end

      it "classifies shebang on non-first line as comment" do
        expect(parser.classify_line("#!/usr/bin/env ruby", line_number: 5)).to eq(:comment)
      end

      it "classifies magic comments" do
        expect(parser.classify_line("# frozen_string_literal: true")).to eq(:magic_comment)
        expect(parser.classify_line("# encoding: utf-8")).to eq(:magic_comment)
        expect(parser.classify_line("# coding: utf-8")).to eq(:magic_comment)
      end
    end

    context "with blank lines" do
      it "classifies empty lines as blank" do
        expect(parser.classify_line("")).to eq(:blank)
        expect(parser.classify_line("   ")).to eq(:blank)
        expect(parser.classify_line("\t")).to eq(:blank)
      end
    end

    context "with code lines" do
      it "classifies regular code as code" do
        expect(parser.classify_line("puts 'hello'")).to eq(:code)
        expect(parser.classify_line("class Foo")).to eq(:code)
        expect(parser.classify_line("def bar")).to eq(:code)
      end
    end
  end

  describe "string containing import keyword detection" do
    context "with strings containing 'require'" do
      it "treats puts with require in string as code" do
        expect(parser.classify_line('puts "require json"')).to eq(:code)
        expect(parser.classify_line("puts 'require json'")).to eq(:code)
      end

      it "treats variable assignment with require in string as code" do
        expect(parser.classify_line('msg = "you need to require json"')).to eq(:code)
        expect(parser.classify_line("msg = 'you need to require json'")).to eq(:code)
      end

      it "treats method call with require in string as code" do
        expect(parser.classify_line('error("Please require the gem first")'))
          .to eq(:code)
      end

      it "treats desc with require in string as code" do
        expect(parser.classify_line('desc "require the json gem"')).to eq(:code)
      end
    end

    context "with actual require statements" do
      it "still classifies real require statements correctly" do
        expect(parser.classify_line("require 'json'")).to eq(:require)
        expect(parser.classify_line('require "json"')).to eq(:require)
        expect(parser.classify_line("  require 'json'")).to eq(:require)
      end

      it "handles require with inline comment" do
        expect(parser.classify_line("require 'json' # load json")).to eq(:require)
      end
    end

    context "with strings containing other import keywords" do
      it "treats strings with include as code" do
        expect(parser.classify_line('puts "include Enumerable"')).to eq(:code)
      end

      it "treats strings with extend as code" do
        expect(parser.classify_line('msg = "extend ActiveSupport"')).to eq(:code)
      end

      it "treats strings with autoload as code" do
        expect(parser.classify_line('doc "autoload :Foo, bar"')).to eq(:code)
      end
    end
  end

  describe "#has_skip_directive?" do
    it "detects isort:skip directive" do
      expect(parser.has_skip_directive?("require 'json' # isort:skip")).to be true
      expect(parser.has_skip_directive?("require 'json' # isort: skip")).to be true
      expect(parser.has_skip_directive?("require 'json' # ISORT:SKIP")).to be true
    end

    it "returns false for lines without skip directive" do
      expect(parser.has_skip_directive?("require 'json'")).to be false
      expect(parser.has_skip_directive?("# just a comment")).to be false
    end

    it "does not match skip_file as skip" do
      expect(parser.has_skip_directive?("# isort:skip_file")).to be false
    end
  end

  describe "#has_skip_file_directive?" do
    it "detects isort:skip_file directive" do
      expect(parser.has_skip_file_directive?("# isort:skip_file")).to be true
      expect(parser.has_skip_file_directive?("# isort: skip_file")).to be true
      expect(parser.has_skip_file_directive?("# ISORT:SKIP_FILE")).to be true
    end

    it "returns false for regular skip directive" do
      expect(parser.has_skip_file_directive?("require 'json' # isort:skip")).to be false
    end
  end

  describe "#extract_indentation" do
    it "extracts leading spaces" do
      expect(parser.extract_indentation("  require 'json'")).to eq("  ")
      expect(parser.extract_indentation("    include Foo")).to eq("    ")
    end

    it "extracts leading tabs" do
      expect(parser.extract_indentation("\trequire 'json'")).to eq("\t")
      expect(parser.extract_indentation("\t\tinclude Foo")).to eq("\t\t")
    end

    it "returns empty string for no indentation" do
      expect(parser.extract_indentation("require 'json'")).to eq("")
    end
  end

  describe "#import_type?" do
    it "returns true for import types" do
      expect(parser.import_type?(:require)).to be true
      expect(parser.import_type?(:require_relative)).to be true
      expect(parser.import_type?(:include)).to be true
      expect(parser.import_type?(:extend)).to be true
      expect(parser.import_type?(:autoload)).to be true
      expect(parser.import_type?(:using)).to be true
    end

    it "returns false for non-import types" do
      expect(parser.import_type?(:comment)).to be false
      expect(parser.import_type?(:blank)).to be false
      expect(parser.import_type?(:code)).to be false
    end
  end
end

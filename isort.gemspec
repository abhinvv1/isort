# frozen_string_literal: true

require_relative "lib/isort/version"

Gem::Specification.new do |spec|
  spec.name = "isort"
  spec.version = Isort::VERSION
  spec.authors = ["abhinvv1"]
  spec.email = ["abhinav.p@browserstack.com"]
  spec.files = Dir["lib/**/*", "exe/*", "README.md", "LICENSE.txt"]
  spec.executables = ["isort"]
  spec.require_paths = ["lib"]
  spec.bindir = "exe"
  spec.summary = "Automatic import sorting for Ruby - sort require, include, extend and more"
  spec.description = <<~DESC.gsub("\n", " ").strip
    isort automatically sorts and organizes import statements in Ruby files.
    It groups imports into sections (stdlib, third-party, first-party, local),
    sorts alphabetically within each section, removes duplicates, and preserves comments.
    Supports require, require_relative, include, extend, autoload, and using statements.
    Features include: check mode for CI integration, diff preview, atomic mode with
    syntax validation, skip directives for fine-grained control, and recursive
    directory processing. Inspired by Python's isort.
  DESC

  spec.homepage = "https://github.com/abhinvv1/isort"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/abhinvv1/isort"
  spec.metadata["changelog_uri"] = "https://github.com/abhinvv1/isort"
  spec.metadata["github_repo"] = "ssh://github.com/abhinvv1/isort"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "optparse", "~> 0.2.0"
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

# frozen_string_literal: true

require_relative 'lib/alces_sacct/version'

Gem::Specification.new do |spec|
  spec.name = 'alces_sacct'
  spec.version = AlcesSacct::VERSION
  spec.authors = ['AdamJ2009']
  spec.email = ['adamdj2009@gmail.com']

  spec.summary = 'CLI tool for parsing and reporting Slurm sacct job accounting data.'
  spec.description = 'AlcesSacct aggregates and formats Slurm sacct output into detailed user and partition reports.'
  spec.homepage = 'https://github.com/AdamJ2009/alces_sacct'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[Gemfile .gitignore .rubocop.yml spec/])
      f.end_with?('.csv')
    end
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'dry-cli', '~> 1.0'
end

# frozen_string_literal: true

require 'rake'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'jekyll'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = Dir.glob('spec/*_spec.rb')
  t.rspec_opts = '--format documentation'
end

# Rake Jekyll tasks
task :build do
  puts 'Building site...'.bold
  Jekyll::Commands::Build.process(profile: true)
end

task :clean do
  puts 'Cleaning up _site...'.bold
  Jekyll::Commands::Clean.process({})
end

task :htmlproofer do
  require 'html-proofer'

  options = {
    ignore_status_codes: [429, 302],
    ignore_urls: [/twitter.com/, /demozoo.org/, /bitbearmusic.bandcamp.com/, /soundcloud.com/],
    hydra: { max_concurrency: 1 },
    cache: { timeframe: { external: '1w' } },
  }
  HTMLProofer.check_directory("./_site", options).run
end

task default: ['spec']

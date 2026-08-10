# frozen_string_literal: true

require 'rake'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'jekyll'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = Dir.glob('spec/*_spec.rb')
  t.rspec_opts = '--format documentation'
end

namespace :codecov do
  desc 'Uploads the latest SimpleCov result set to codecov.io'
  task :upload do
    require 'simplecov'
    require 'codecov'

    formatter = SimpleCov::Formatter::Codecov.new
    formatter.format(SimpleCov::ResultMerger.merged_result)
  end
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

namespace :covers do
  desc 'Generates 2160×2160 @2x twins from the git-ignored covers-master/ sources'
  task :'2x' do
    covers_dir = File.join(__dir__, 'assets', 'images', 'covers')
    masters_dir = File.join(__dir__, 'covers-master')
    abort 'covers-master/ does not exist' unless Dir.exist?(masters_dir)

    Dir.glob(File.join(covers_dir, '*.jpg'))
       .reject { |f| f.include?('@2x.jpg') }
       .each do |cover|
      name = File.basename(cover, '.jpg')
      master = Dir.glob(File.join(masters_dir, "#{name}.*")).first
      next if master.nil?

      twin = File.join(covers_dir, "#{name}@2x.jpg")
      next if File.exist?(twin) && File.mtime(twin) >= File.mtime(master)

      system('sips', '-s', 'format', 'jpeg', '-z', '2160', '2160', master, '--out', twin) ||
        abort("Failed to generate #{twin} from #{master}")
      puts "Generated #{twin}"
    end
  end
end

task :htmlproofer do
  require 'html-proofer'

  options = {
    ignore_status_codes: [429, 302],
    ignore_urls: [
      /twitter.com/,
      /demozoo.org/,
      /bitbearmusic.bandcamp.com/,
      /soundcloud.com/,
      /api.modarchive.org/,
    ],
    hydra: { max_concurrency: 1 },
    cache: { timeframe: { external: '1w' } },
  }
  HTMLProofer.check_directory("./_site", options).run
end

task default: ['spec']

# frozen_string_literal: true

require 'rake'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'jekyll'
require_relative 'lib/cover_art_generator'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = Dir.glob('spec/*_spec.rb')
  t.rspec_opts = '--format documentation'
end

# Rake Jekyll tasks
desc 'Builds the site into _site/ and reformats the output with Tidy'
task :build do
  puts 'Building site...'.bold
  Jekyll::Commands::Build.process(profile: true)
  Rake::Task[:prettify].invoke
end

desc 'Reformats every built page with consistent indentation via HTML Tidy'
task :prettify do
  puts 'Prettifying HTML output...'.bold

  tidy_options = [
    '-modify',
    '-indent',
    '-wrap', '0',
    '-quiet',
    '-utf8',
    '--tidy-mark', 'no',
    # Tidy considers elements with no text content "empty" and drops them by
    # default, but this site relies on empty <span> elements (e.g. for
    # CSS-driven icons) that must be preserved.
    '--drop-empty-elements', 'no',
    '--show-warnings', 'no'
  ].freeze

  Dir.glob(File.join(__dir__, '_site', '**', '*.html')).each do |file|
    # Tidy exits 0 for a clean document, 1 for warnings (expected, e.g. proprietary
    # attributes like aria-description), and 2 for errors; none of those indicate a
    # failure to run, only `nil` (tidy binary missing) does.
    result = system('tidy', *tidy_options, file, out: File::NULL, err: File::NULL)
    abort 'tidy is not installed; run `brew install tidy-html5`' if result.nil?
  end
end

desc 'Removes the built _site/ directory'
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

  desc 'Generates cover art for any track post that does not have any yet'
  task :generate do
    generated = CoverArtGenerator.generate!(source_dir: __dir__)
    puts generated.empty? ? 'Every track already has cover art.' : "Generated cover art for: #{generated.join(', ')}"
  end
end

desc 'Checks the built site for broken links, images, and scripts'
task :htmlproofer do
  require 'html-proofer'

  options = {
    ignore_status_codes: [429, 302, 502, 503],
    ignore_urls: [
      /twitter.com/,
      /demozoo.org/,
      /bandcamp.com/,
      /soundcloud.com/,
      /api.modarchive.org/,
      /moduloone.com/,
      /flickr.com/,
      /help.thenounproject.com/,
      /trsac.dk/,
      /web.archive.org/
    ],
    hydra: { max_concurrency: 1 },
    cache: { timeframe: { external: '1w' } }
  }
  HTMLProofer.check_directory('./_site', options).run
end

task default: ['spec']

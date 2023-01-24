# frozen_string_literal: true

ruby '2.7.7'

source 'https://rubygems.org'

gem 'jekyll'

group :jekyll_plugins do
  gem 'jekyll-feed'
  gem 'jekyll-sitemap'
end

group :libs do
  gem 'bytesize'
  gem 'nokogiri'
end

group :development do
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
end

group :test do
  gem 'codecov', require: false
  gem 'its', require: false
  gem 'rake', require: false
  gem 'rspec', require: false
  gem 'rspec-html-matchers', require: false
end

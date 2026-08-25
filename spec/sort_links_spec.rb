# frozen_string_literal: true

require_relative '../_plugins/liquid_filters/link_filters'

RSpec.describe 'sort_links' do # rubocop:disable RSpec/DescribeClass
  include Jekyll::LinkFilters

  it 'orders links by the fixed brand priority' do
    links = [
      'https://youtube.com/watch?v=abc',
      'https://moduloone.bandcamp.com/track/x',
      'https://soundcloud.com/bitbear/x',
      'https://example.com/unknown-thing',
      'https://open.spotify.com/track/x',
      'https://modarchive.org/?moduleid=1'
    ]
    brands = sort_links(links).map { |link| link_brand(link) }
    expect(brands).to eq(%w[bandcamp soundcloud spotify youtube modarchive unknown])
  end

  it 'sorts unknown links after every known brand' do
    links = [
      'https://example.com/a',
      'https://example.com/b',
      'https://bandcamp.com/x',
      'https://soundcloud.com/x'
    ]
    sorted = sort_links(links)
    expect(sorted.last(2)).to eq(['https://example.com/a', 'https://example.com/b'])
  end

  it 'preserves original order within the same brand' do
    links = [
      'https://soundcloud.com/bitbear/second',
      'https://soundcloud.com/bitbear/first'
    ]
    expect(sort_links(links)).to eq(links)
  end

  it 'handles hash-style link entries as well as plain URLs' do
    links = [
      { 'youtube' => 'https://youtube.com/watch?v=abc' },
      { 'bandcamp' => 'https://moduloone.bandcamp.com/track/x' }
    ]
    brands = sort_links(links).map { |link| link_brand(link) }
    expect(brands).to eq(%w[bandcamp youtube])
  end
end

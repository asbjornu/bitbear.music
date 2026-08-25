# frozen_string_literal: true

require_relative 'spec_helper'
require_relative 'support/site_fixtures'

describe 'iterator back button' do
  include SiteFixtures

  def iterator(path)
    Nokogiri::HTML(read_utf8(File.join(source_root, '_site', path))).at_css('nav.iterator')
  end

  def back_link(path)
    iterator(path).at_css('a[rel="back"]')
  end

  it 'links a track back to its single/album/EP release, not to itself' do
    link = back_link('music/sunset-through-the-rain.html')

    expect(link['href']).to eq('/music/albums/sunset-through-the-rain')
    expect(link.text.strip).to eq('Back to single')
    expect(link.parent.parent['data-tooltip']).to eq('Go back to the “Sunset Through The Rain” single')
  end

  it 'links a release page back to the Music index' do
    link = back_link('music/albums/sunset-through-the-rain.html')

    expect(link['href']).to eq('/music/')
    expect(link.text.strip).to eq('Back to Music')
    expect(link.parent.parent['data-tooltip']).to eq('Go back to the “Music” page')
  end

  it 'links a category page back to its parent index, without a doubled slash' do
    link = back_link('music/legacy/cool-interpreter.html')

    expect(link['href']).to eq('/music/legacy/')
    expect(link.parent.parent['data-tooltip']).to eq('Go back to the “Bitbear\'s Legacy Music” page')
  end

  it "tells prev/next tooltips apart from tracks and releases" do
    nav = iterator('music/sunset-through-the-rain.html')
    prev = nav.at_css('a[rel="prev"]')
    next_link = nav.at_css('a[rel="next"]')

    expect(prev.parent.parent['data-tooltip']).to eq('Go to the “That Flateby Feeling” track')
    expect(next_link.parent.parent['data-tooltip'])
      .to eq('Go to the “Modulo One - The King And The Priest (Bitbear Remix)” track')
  end

  it "describes a remix kit's back-to-track button" do
    link = back_link('music/move/remix-kit/index.html')

    expect(link['href']).to eq('/music/move')
    expect(link.parent.parent['data-tooltip']).to eq('Go to the “Move” track')
  end
end

# frozen_string_literal: true

require_relative 'spec_helper'

require 'json'

describe 'Pico CSS integration' do
  def read_utf8(path)
    File.binread(path).force_encoding(Encoding::UTF_8)
  end

  let(:site_root) { File.expand_path('..', __dir__) }
  let(:css_path) { File.join(site_root, '_site', 'assets', 'scss', 'bitbear.css') }
  let(:css) { read_utf8(css_path) }
  let(:legacy_path) { File.join(site_root, '_site', 'music', 'legacy', 'call-of-the-totem.html') }
  let(:legacy) { read_utf8(legacy_path) }

  it 'compiles the stylesheet' do
    expect(File).to exist(css_path)
  end

  describe 'compiled stylesheet' do
    it 'includes Pico CSS' do
      expect(css).to include('--pico-')
    end

    it 'keeps the 16px root font-size so rem-based dimensions are not inflated' do
      expect(css).to include('--pico-font-size: 1rem')
    end

    it 'keeps the dark background theme' do
      expect(css).to include('--pico-background-color: #000')
    end

    it 'keeps the purple primary button color' do
      expect(css).to include('--pico-primary-background: rgba(65, 34, 142, 0.6)')
    end

    it 'keeps the header padding-top so main does not overlap the nav' do
      expect(css).to match(/body\s*>\s*header\{[^}]*padding-top:6rem/)
    end

    it 'restores content-box sizing for layout while Pico buttons stay border-box' do
      expect(css).to include('*,*::before,*::after{box-sizing:content-box')
      expect(css).to include('a[role=button]{box-sizing:border-box')
    end

    it 'keeps the #cover wrapper styling for media embeds' do
      expect(css).to include(
        'main .media #cover{align-self:start;padding:.5em;margin:0 0 .5em 1em;border:1px solid #41228e;border-radius:10px'
      )
    end

    it 'keeps the iterator buttons equally spaced with no outer margins' do
      expect(css).to include('nav.iterator ol{margin:0;padding:0;display:flex;flex-wrap:wrap;gap:1em')
    end

    it 'masks the unknown link icon with the noun project asset' do
      expect(css).to include('.icon.icon-unknown')
      expect(css).to include('url("/assets/images/services/unknown.svg")')
    end

    it 'masks the demozoo link icon with the black D in a white square asset' do
      expect(css).to include('.icon.icon-demozoo')
      expect(css).to include('url("/assets/images/services/demozoo.svg")')
    end

    it 'masks the youtube link icon with the play button asset' do
      expect(css).to include('.icon.icon-youtube')
      expect(css).to include('url("/assets/images/services/youtube.svg")')
    end

    it 'masks the modarchive link icon with the M asset' do
      expect(css).to include('.icon.icon-modarchive')
      expect(css).to include('url("/assets/images/services/modarchive.svg")')
    end

    it 'masks the amp link icon with the AMP asset' do
      expect(css).to include('.icon.icon-amp')
      expect(css).to include('url("/assets/images/services/amp.svg")')
    end

    it 'masks the nectarine link icon with the nectarine asset' do
      expect(css).to include('.icon.icon-nectarine')
      expect(css).to include('url("/assets/images/services/nectarine.svg")')
    end
  end

  describe 'generated markup' do
    it 'forces the dark color scheme on the html element' do
      expect(read_utf8(File.join(site_root, '_site', 'index.html')))
        .to have_tag('html', with: { 'data-theme' => 'dark' })
    end

    it 'renders iterator navigation as Pico button-styled links' do
      expect(legacy).to have_tag('nav', with: { class: 'iterator' }) do
        with_tag('a', with: { role: 'button' })
      end
      expect(legacy).to have_tag('a', with: { role: 'button', rel: 'prev' })
      expect(legacy).to have_tag('a', with: { role: 'button', rel: 'back' })
    end

    it 'wraps YouTube embeds in the styled #cover element' do
      expect(legacy).to have_tag('div', with: { id: 'cover' })
      iframe = Nokogiri::HTML(legacy).at_css('div#cover iframe')
      expect(iframe['src']).to match(%r{youtube\.com/embed/})
    end

    it 'renders unknown links with the unknown icon' do
      page = read_utf8(File.join(site_root, '_site', 'music', 'the-king-and-the-priest.html'))
      expect(page).to have_tag('li', with: { class: 'unknown' }) do
        with_tag('a', with: {
                   href: 'https://moduloone.com/news/the-king-and-the-priest-out-1-september-with-bitbear-remix/',
                   target: '_blank',
                   'aria-description' => 'moduloone.com'
                 })
        with_tag('span', with: { class: 'icon icon-unknown' })
      end
    end

    it 'derives known link hrefs from the full URL in the link value' do
      page = read_utf8(File.join(site_root, '_site', 'music', 'albums', 'scene-so-far.html'))
      expect(page).to have_tag('a', with: { href: 'https://bitbearmusic.bandcamp.com/album/scene-so-far' })
      expect(page).to have_tag('a', with: { href: 'https://open.spotify.com/album/1U1mATmmalOlHPnX98UNFl' })
    end

    it 'renders demozoo links with the demozoo icon' do
      page = read_utf8(File.join(site_root, '_site', 'music', 'sliding-away.html'))
      expect(page).to have_tag('li', with: { class: 'demozoo' }) do
        with_tag('a', with: {
                   href: 'https://demozoo.org/music/51159/',
                   target: '_blank',
                   'aria-description' => 'View “Sliding Away” on Demozoo'
                 })
        with_tag('span', with: { class: 'icon icon-demozoo' })
      end
    end

    it 'renders youtube links with the youtube icon' do
      page = read_utf8(File.join(site_root, '_site', 'music', 'legacy', 'final-countdown.html'))
      expect(page).to have_tag('li', with: { class: 'youtube' }) do
        with_tag('a', with: {
                   href: 'https://www.youtube.com/watch?v=R7mHV_dyYeA',
                   target: '_blank',
                   'aria-description' => 'Watch “Final Countdown” on Youtube'
                 })
        with_tag('span', with: { class: 'icon icon-youtube' })
      end
    end

    it 'derives the modarchive download button from a link' do
      page = read_utf8(File.join(site_root, '_site', 'music', 'legacy', 'final-countdown.html'))
      expect(page).to have_tag('a', with: {
                                 role: 'button',
                                 href: 'https://api.modarchive.org/downloads.php?moduleid=199582'
                               })
    end

    it 'renders modarchive and amp links as icons pointing at their web pages, not the download files' do
      page = read_utf8(File.join(site_root, '_site', 'music', 'legacy', 'final-countdown.html'))
      expect(page).to have_tag('li', with: { class: 'modarchive' }) do
        with_tag('a', with: {
                   href: 'https://modarchive.org/index.php?request=view_by_moduleid&query=199582',
                   target: '_blank'
                 })
        with_tag('span', with: { class: 'icon icon-modarchive' })
      end
      expect(page).to have_tag('li', with: { class: 'amp' }) do
        with_tag('a', with: {
                   href: 'https://amp.dascene.net/analyzer2.php?idx=159586',
                   target: '_blank'
                 })
        with_tag('span', with: { class: 'icon icon-amp' })
      end
    end
  end
end

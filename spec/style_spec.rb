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
      expect(css).to match(/header\{[^}]*padding-top:6rem/)
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
      expect(css).to include('nav.iterator ol{margin:0;padding:0;display:flex;gap:1em')
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
  end
end

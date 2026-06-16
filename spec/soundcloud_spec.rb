# frozen_string_literal: true

require_relative '../_plugins/soundcloud'

describe Jekyll::SoundCloudTag do
  include_context 'shared'
  music_index = File.absolute_path(File.join(@dest_dir, 'music', 'index.html'))

  describe music_index do
    subject { File.read(music_index) }

    it {
      expect(File).to exist(music_index)
    }

    it 'has expected first card deck' do
      is_expected.to have_tag('article', with: { itemprop: 'track', itemscope: '', itemtype: 'http://schema.org/MusicRecording' }) do
        with_tag('h3', with: { itemprop: 'name' }) do
          with_tag('a', with: { itemprop: 'url', href: 'https://soundcloud.com/bitbear/sunset-through-the-rain' }, text: 'Sunset Through The Rain')
        end
        with_tag('iframe[src*="856873432"]', with: { width: '100%', height: '100', scrolling: 'no', frameborder: 'no' }) do |match|
          expect(match.current_scope.size).to eq 1

          match.current_scope.each do |iframe|
            src = iframe['src']
            expect(src).to eq 'https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F856873432&color=%23ff5500&auto_play=false&hide_related=false&show_comments=true&show_user=true&show_reposts=false&show_teaser=true&visual=true'
          end
        end
      end
    end
  end
end

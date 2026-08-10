# frozen_string_literal: true

require 'liquid'
require_relative '../_plugins/liquid_filters'

describe Jekyll::LiquidFilters do
  subject(:instance) { Class.new { include Jekyll::LiquidFilters }.new }

  describe '#reject with key and value' do
    context 'with scalar values' do
      let(:items) do
        [
          { 'title' => 'A', 'list' => true },
          { 'title' => 'B', 'list' => false },
          { 'title' => 'C', 'list' => true }
        ]
      end

      it 'removes items matching the key/value' do
        result = instance.reject(items, 'list', false)
        expect(result.size).to eq(2)
        expect(result.map { |i| i['title'] }).to contain_exactly('A', 'C')
      end

      it 'returns all items when none match' do
        result = instance.reject(items, 'list', 'nonexistent')
        expect(result.size).to eq(3)
      end

      it 'returns empty array when all items match' do
        all_match = [
          { 'title' => 'A', 'list' => true },
          { 'title' => 'B', 'list' => true }
        ]
        result = instance.reject(all_match, 'list', true)
        expect(result).to be_empty
      end

      it 'returns empty array for empty input' do
        result = instance.reject([], 'foo', 'bar')
        expect(result).to be_empty
      end
    end

    context 'with array values' do
      let(:items) do
        [
          { 'title' => 'A', 'categories' => %w[music] },
          { 'title' => 'B', 'categories' => %w[music legacy] },
          { 'title' => 'C', 'categories' => %w[music electronic] },
          { 'title' => 'D', 'categories' => %w[legacy] }
        ]
      end

      it 'removes items whose array includes the value' do
        result = instance.reject(items, 'categories', 'legacy')
        expect(result.size).to eq(2)
        expect(result.map { |i| i['title'] }).to contain_exactly('A', 'C')
      end

      it 'removes nothing when the value is not in any array' do
        result = instance.reject(items, 'categories', 'jazz')
        expect(result.size).to eq(4)
      end

      it 'removes everything when the value is in every array' do
        every = [
          { 'title' => 'A', 'categories' => %w[music legacy] },
          { 'title' => 'B', 'categories' => %w[sound legacy] }
        ]
        result = instance.reject(every, 'categories', 'legacy')
        expect(result).to be_empty
      end

      it 'works with single-element arrays' do
        result = instance.reject(items, 'categories', 'music')
        expect(result.size).to eq(1)
        expect(result.first['title']).to eq('D')
      end

      it 'handles empty arrays' do
        with_empty = items + [{ 'title' => 'E', 'categories' => [] }]
        result = instance.reject(with_empty, 'categories', 'legacy')
        expect(result.size).to eq(3)
        expect(result.map { |i| i['title'] }).to contain_exactly('A', 'C', 'E')
      end

      context 'when the key uses the singular form (category) but data uses plural (categories)' do
        it 'falls back to the plural key' do
          result = instance.reject(items, 'category', 'legacy')
          expect(result.size).to eq(2)
          expect(result.map { |i| i['title'] }).to contain_exactly('A', 'C')
        end

        it 'returns all items when the plural array does not include the value' do
          result = instance.reject(items, 'category', 'jazz')
          expect(result.size).to eq(4)
        end

        it 'handles empty categories array via singular key' do
          with_empty = items + [{ 'title' => 'E', 'categories' => [] }]
          result = instance.reject(with_empty, 'category', 'legacy')
          expect(result.size).to eq(3)
          expect(result.map { |i| i['title'] }).to contain_exactly('A', 'C', 'E')
        end
      end
    end
  end

  describe '#reject with dot-separated path' do
    let(:items) do
      [
        { 'title' => 'A', 'album' => { 'slug' => 'alpha' } },
        { 'title' => 'B', 'album' => nil },
        { 'title' => 'C', 'album' => { 'slug' => '' } },
        { 'title' => 'D', 'album' => { 'slug' => 'beta' } },
        { 'title' => 'E' },
        { 'title' => 'F', 'album' => {} }
      ]
    end

    it 'rejects items with a truthy nested value' do
      result = instance.reject(items, 'album.slug')
      expect(result.size).to eq(4)
      expect(result.map { |i| i['title'] }).to contain_exactly('B', 'C', 'E', 'F')
    end

    it 'rejects posts where album.slug has a non-empty value like some-slug' do
      has_slug = [
        { 'title' => 'A', 'album' => { 'slug' => 'sunset-through-the-rain' } },
        { 'title' => 'B', 'album' => { 'slug' => 'beyond-fantasy' } }
      ]
      result = instance.reject(has_slug, 'album.slug')
      expect(result).to be_empty
    end

    it 'does not reject posts where album has other sub-properties like kind but no slug' do
      other_props_only = [
        { 'title' => 'A', 'album' => { 'kind' => 'EP' } },
        { 'title' => 'B', 'album' => { 'cover' => 'art.jpg' } }
      ]
      result = instance.reject(other_props_only, 'album.slug')
      expect(result.size).to eq(2)
    end

    it 'does not reject posts with an empty album hash' do
      result = instance.reject([{ 'title' => 'A', 'album' => {} }], 'album.slug')
      expect(result.size).to eq(1)
    end

    it 'returns empty array when all items have the nested value' do
      all_have = [
        { 'title' => 'A', 'album' => { 'slug' => 'alpha' } },
        { 'title' => 'B', 'album' => { 'slug' => 'beta' } }
      ]
      result = instance.reject(all_have, 'album.slug')
      expect(result).to be_empty
    end

    it 'returns all items when none have the nested value' do
      none_have = [
        { 'title' => 'A', 'album' => nil },
        { 'title' => 'B' }
      ]
      result = instance.reject(none_have, 'album.slug')
      expect(result.size).to eq(2)
    end

    it 'returns empty array for empty input' do
      result = instance.reject([], 'album.slug')
      expect(result).to be_empty
    end
  end

describe '#sort_by' do
    let(:items) do
      [
        { 'title' => 'Rise', 'album' => { 'position' => 6 } },
        { 'title' => 'Move', 'album' => { 'position' => 1 } },
        { 'title' => 'Raise The Dead', 'album' => { 'position' => 3 } }
      ]
    end

    it 'sorts items by a dot-separated path' do
      result = instance.sort_by(items, 'album.position')
      expect(result.map { |i| i['title'] }).to eq(['Move', 'Raise The Dead', 'Rise'])
    end

    it 'sorts items by a simple key' do
      result = instance.sort_by(items, 'title')
      expect(result.map { |i| i['title'] }).to eq(['Move', 'Raise The Dead', 'Rise'])
    end

    it 'sorts items with a missing nested value first' do
      with_missing = items + [{ 'title' => 'No Album', 'album' => nil }]
      result = instance.sort_by(with_missing, 'album.position')
      expect(result.first['title']).to eq('No Album')
      expect(result.map { |i| i['title'] }).to eq(['No Album', 'Move', 'Raise The Dead', 'Rise'])
    end

    it 'returns empty array for empty input' do
      expect(instance.sort_by([], 'album.position')).to be_empty
    end

    it 'preserves order of items with equal values' do
      tied = [
        { 'title' => 'A', 'album' => { 'position' => 1 } },
        { 'title' => 'B', 'album' => { 'position' => 1 } }
      ]
      result = instance.sort_by(tied, 'album.position')
      expect(result.map { |i| i['title'] }).to eq(%w[A B])
    end
  end

  describe '#zip_contents' do
    def with_source
      site = instance_double('Jekyll::Site', source: File.expand_path('..', __dir__))
      context = instance_double('Liquid::Context', registers: { site: site })
      instance.instance_variable_set(:@context, context)
    end

    it 'strips the top-level archive folder from every listing entry' do
      with_source
      entries = instance.zip_contents('Bitbear-Planeswalker-Remix_Kit.zip')
      expect(entries).not_to be_empty
      expect(entries).not_to include(start_with('Planeswalker/'))
    end

    it 'keeps the folder structure below the archive root' do
      with_source
      entries = instance.zip_contents('Bitbear-Planeswalker-Remix_Kit.zip')
      expect(entries).to include(start_with('Stems/'))
    end

    it 'strips the differently named folder of the sunset kit' do
      with_source
      entries = instance.zip_contents('Bitbear-Sunset_Through_The_Rain-Remix_Kit.zip')
      expect(entries).not_to include(start_with('Bitbear-Sunset-Through-The-Rain-Remix-Kit/'))
      expect(entries).to include('Presets/arp.fxp')
    end
  end

  describe '#high_res' do
    def static_file(url)
      instance_double('Jekyll::StaticFile', url: url)
    end

    def with_site(files: [])
      site = instance_double('Jekyll::Site', static_files: files)
      context = instance_double('Liquid::Context', registers: { site: site })
      instance.instance_variable_set(:@context, context)
    end

    it 'returns the @2x variant URL when it exists' do
      with_site(files: [static_file('/assets/images/covers/bitwerk@2x.jpg')])
      expect(instance.high_res('/assets/images/covers/bitwerk.jpg'))
        .to eq('/assets/images/covers/bitwerk@2x.jpg')
    end

    it 'returns nil when the @2x variant does not exist' do
      with_site(files: [static_file('/assets/images/covers/bitwerk.jpg')])
      expect(instance.high_res('/assets/images/covers/bitwerk.jpg')).to be_nil
    end

    it 'supports png and webp extensions' do
      with_site(files: [static_file('/assets/images/covers/art@2x.webp')])
      expect(instance.high_res('/assets/images/covers/art.webp'))
        .to eq('/assets/images/covers/art@2x.webp')
    end

    it 'returns nil for empty input' do
      with_site
      expect(instance.high_res('')).to be_nil
    end

    it 'returns nil for input without an image extension' do
      with_site
      expect(instance.high_res('/assets/images/covers/bitwerk')).to be_nil
    end

    it 'returns nil when no Jekyll context is available' do
      expect(instance.high_res('/assets/images/covers/bitwerk.jpg')).to be_nil
    end
  end
end

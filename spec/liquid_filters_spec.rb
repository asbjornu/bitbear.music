# frozen_string_literal: true

require 'liquid'
require_relative '../_plugins/liquid_filters'

describe Jekyll::LiquidFilters do
  describe '#ordinalize' do
    let(:template) { Liquid::Template.parse('{{ input | ordinalize }}') }

    context 'st suffix' do
      it '1st' do
        expect(template.render('input' => 1)).to eq('1st')
      end

      it '21st' do
        expect(template.render('input' => 21)).to eq('21st')
      end

      it '31st' do
        expect(template.render('input' => 31)).to eq('31st')
      end
    end

    context 'nd suffix' do
      it '2nd' do
        expect(template.render('input' => 2)).to eq('2nd')
      end

      it '22nd' do
        expect(template.render('input' => 22)).to eq('22nd')
      end
    end

    context 'rd suffix' do
      it '3rd' do
        expect(template.render('input' => 3)).to eq('3rd')
      end

      it '23rd' do
        expect(template.render('input' => 23)).to eq('23rd')
      end
    end

    context 'th suffix' do
      it '0th' do
        expect(template.render('input' => 0)).to eq('0th')
      end

      %w[4th 5th 6th 7th 8th 9th 10th].each do |pair|
        num = pair.to_i
        it pair do
          expect(template.render('input' => num)).to eq(pair)
        end
      end

      it '11th' do
        expect(template.render('input' => 11)).to eq('11th')
      end

      it '12th' do
        expect(template.render('input' => 12)).to eq('12th')
      end

      it '13th' do
        expect(template.render('input' => 13)).to eq('13th')
      end

      it '20th' do
        expect(template.render('input' => 20)).to eq('20th')
      end

      it '24th' do
        expect(template.render('input' => 24)).to eq('24th')
      end
    end

    context 'with string input' do
      it 'ordinalizes numeric strings' do
        expect(template.render('input' => '1')).to eq('1st')
      end

      it 'preserves leading zeros' do
        expect(template.render('input' => '01')).to eq('01st')
      end
    end
  end

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
end

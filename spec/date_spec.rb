# frozen_string_literal: true

require 'its'
require 'liquid'
require_relative '../_plugins/date'

describe Jekyll::DateTag do
  subject(:date) { described_class.parse('date', input, nil, Liquid::ParseContext.new) }

  context 'with format' do
    let(:input) { "format: '%B %Y'" }
    its(:raw) { is_expected.to eq("date format: '%B %Y'") }
    its(:render, Liquid::Context.new({ 'page' => { 'date' => '2020-08-23' } })) {
      is_expected.to eq('<abbr title="2020-08-23">August 2020</abbr>')
    }
  end

  context 'with format and date' do
    let(:input) { "'2018-01-01', format: '%B %Y'" }
    its(:raw) { is_expected.to eq("date '2018-01-01', format: '%B %Y'") }
    its(:render, Liquid::Context.new({ 'page' => { 'date' => '2020-08-23' } })) {
      is_expected.to eq('<abbr title="2018-01-01">January 2018</abbr>')
    }
  end

  context 'valid dates' do
    let(:input) { '2018-01-01' }
    its(:raw) { is_expected.to eq('date 2018-01-01') }
    its(:render, Liquid::Context.new({ 'page' => { 'date' => '2020-08-23' } })) {
      is_expected.to eq('<abbr title="2018-01-01">Monday, January 1st 2018</abbr>')
    }
  end

  context 'nil input date, valid page date' do
    let(:input) { nil }
    its(:raw) { is_expected.to eq('date ') }
    its(:render, Liquid::Context.new({ 'page' => { 'date' => '2020-08-23' } })) {
      is_expected.to eq('<abbr title="2020-08-23">Sunday, August 23rd 2020</abbr>')
    }
  end

  context 'nil date' do
    let(:input) { nil }
    its(:raw) { is_expected.to eq('date ') }
    its(:render, Liquid::Context.new({ 'page' => { 'date' => nil } })) {
      is_expected.to be_empty
    }
  end

  context 'invalid date' do
    let(:input) { 'abc' }
    its(:raw) { is_expected.to eq('date abc') }

    its(:render, Liquid::Context.new({ 'page' => { 'date' => 'abc' } })) {
      is_expected.to be_empty
    }
  end

  describe('#ordinal') do
    let(:input) { nil }

    context 'st suffix' do
      it '1st' do
        expect(subject.ordinal(1)).to eq('1st')
      end

      it '21st' do
        expect(subject.ordinal(21)).to eq('21st')
      end

      it '31st' do
        expect(subject.ordinal(31)).to eq('31st')
      end
    end

    context 'nd suffix' do
      it '2nd' do
        expect(subject.ordinal(2)).to eq('2nd')
      end

      it '22nd' do
        expect(subject.ordinal(22)).to eq('22nd')
      end
    end

    context 'rd suffix' do
      it '3rd' do
        expect(subject.ordinal(3)).to eq('3rd')
      end

      it '23rd' do
        expect(subject.ordinal(23)).to eq('23rd')
      end
    end

    context 'th suffix' do
      it '0th' do
        expect(subject.ordinal(0)).to eq('0th')
      end

      %w[4th 5th 6th 7th 8th 9th 10th].each do |pair|
        num = pair.to_i
        it pair do
          expect(subject.ordinal(num)).to eq(pair)
        end
      end

      it '11th' do
        expect(subject.ordinal(11)).to eq('11th')
      end

      it '12th' do
        expect(subject.ordinal(12)).to eq('12th')
      end

      it '13th' do
        expect(subject.ordinal(13)).to eq('13th')
      end

      it '20th' do
        expect(subject.ordinal(20)).to eq('20th')
      end

      it '24th' do
        expect(subject.ordinal(24)).to eq('24th')
      end

      it '30th' do
        expect(subject.ordinal(30)).to eq('30th')
      end
    end
  end

  context 'with an ordinal day token' do
    let(:input) { "'2018-01-01', format: '%B {day} %Y'" }
    its(:raw) { is_expected.to eq("date '2018-01-01', format: '%B {day} %Y'") }
    its(:render, Liquid::Context.new({ 'page' => { 'date' => '2020-08-23' } })) {
      is_expected.to eq('<abbr title="2018-01-01">January 1st 2018</abbr>')
    }
  end

  context 'with a date variable' do
    let(:input) { 'post.date' }
    its(:raw) { is_expected.to eq('date post.date') }

    its(:render, Liquid::Context.new({ 'page' => { 'date' => '2020-08-23' }, 'post' => { 'date' => '2018-01-01' } })) {
      is_expected.to eq('<abbr title="2018-01-01">Monday, January 1st 2018</abbr>')
    }
  end
end

# frozen_string_literal: true

require 'yaml'

describe 'cover art' do
  let(:root) { File.expand_path('..', __dir__) }
  let(:covers_dir) { File.join(root, 'assets', 'images', 'covers') }
  let(:covers) do
    Dir.glob(File.join(covers_dir, '*.jpg'))
       .reject { |f| f.include?('@2x.jpg') }
  end

  it 'provides an @2x twin for every 1080×1080 cover' do
    missing = covers.reject { |f| File.exist?(f.sub(/\.jpg\z/, '@2x.jpg')) }
    expect(missing).to be_empty,
                        "Missing @2x twins:\n#{names(missing).join("\n")}"
  end

  it 'only references existing cover files in post front matter' do
    missing = referenced_covers.reject do |cover|
      File.exist?(File.join(covers_dir, cover))
    end
    expect(missing).to be_empty,
                        "Referenced covers not found:\n#{missing.sort.join("\n")}"
  end

  def names(files)
    files.map { |f| File.basename(f) }.sort
  end

  def referenced_covers
    posts = Dir.glob(File.join(root, 'music', '**', '*.md'))
    posts.flat_map { |post| covers_in(front_matter(post)) }.uniq
  end

  def front_matter(path)
    match = File.read(path, encoding: 'UTF-8').match(/\A---\s*\n(.*?)\n---/m)
    return {} if match.nil?

    YAML.safe_load(match[1], permitted_classes: [Date, Time, Symbol], aliases: true) || {}
  end

  def covers_in(data)
    return [] unless data.is_a?(Hash)

    data.flat_map do |key, value|
      if key == 'cover' && value.is_a?(String)
        [value]
      else
        covers_in(value)
      end
    end
  end
end
# frozen_string_literal: true

require 'json'

require_relative 'json_ld/graph_builder'

module Jekyll
  # Renders a single <script type="application/ld+json"> tag containing
  # schema.org structured data. Unlike a Liquid include, the JSON-LD graph is
  # built as a plain Ruby Hash (see json_ld/graph_builder.rb and friends) and
  # serialized with Ruby's JSON library, so escaping and comma-placement are
  # handled correctly by `to_json` instead of by hand-assembled Liquid string
  # concatenation.
  #
  # Every page gets the site-wide MusicGroup entity describing the artist;
  # track pages (layout: post) additionally get a MusicRecording entity, and
  # album pages (layout: album) additionally get a MusicAlbum entity, both
  # linked back to the MusicGroup via byArtist.
  class JsonLdTag < Liquid::Tag
    def render(context)
      site = context.registers[:site]
      page = context['page']
      graph = JsonLd::GraphBuilder.new(site, page, context).graph
      document = { '@context' => 'https://schema.org', '@graph' => graph }

      %(<script type="application/ld+json">#{document.to_json}</script>)
    end
  end
end

Liquid::Template.register_tag('json_ld', Jekyll::JsonLdTag)

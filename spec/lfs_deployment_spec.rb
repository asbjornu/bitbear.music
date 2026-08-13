# frozen_string_literal: true

require_relative 'spec_helper'

require 'yaml'

# Regression coverage for keeping Git LFS-tracked binaries (the remix-kit
# archives) out of the GitHub Pages deployment artifact, which is capped at
# 1 GB. See _plugins/liquid_filters.rb#lfs_media_url and the workflows under
# .github/workflows for the full mechanism.
describe 'Git LFS / GitHub Pages deployment' do
  def source_root
    File.expand_path('..', __dir__)
  end

  def load_workflow(name)
    YAML.safe_load(File.read(File.join(source_root, '.github', 'workflows', name)))
  end

  describe '_config.yml' do
    let(:config) { YAML.safe_load(File.read(File.join(source_root, '_config.yml'))) }

    it 'configures the repository used to build media.githubusercontent.com URLs' do
      expect(config['repository']).to eq('asbjornu/bitbear.music')
    end

    it 'configures the branch used to build media.githubusercontent.com URLs' do
      expect(config['repository_branch']).to eq('main')
    end
  end

  describe '_layouts/remix_kit.html' do
    let(:layout) { File.read(File.join(source_root, '_layouts', 'remix_kit.html')) }

    it 'builds the archive download link through the lfs_media_url filter' do
      expect(layout).to match(/href="\{\{.*\|\s*lfs_media_url\s*\}\}"/)
    end

    it 'does not hard-code a local /assets/remix-kits/ download href' do
      expect(layout).not_to match(%r{href="/assets/remix-kits/})
    end
  end

  describe '.github/workflows/_build.yml' do
    let(:workflow) { load_workflow('_build.yml') }
    let(:build_job) { workflow['jobs']['build'] }
    let(:steps) { build_job['steps'] }

    def step_named(name)
      steps.find { |step| step['name'] == name }
    end

    def step_using(uses)
      steps.find { |step| step['uses'] == uses }
    end

    it 'exposes a boolean production input, defaulting to false' do
      production_input = workflow[true]['workflow_call']['inputs']['production']
      expect(production_input['type']).to eq('boolean')
      expect(production_input['default']).to be(false)
    end

    it 'only checks out Git LFS content for production builds' do
      checkout = step_using('actions/checkout@v7')
      expect(checkout.dig('with', 'lfs')).to eq('${{ inputs.production }}')
    end

    it 'sets JEKYLL_ENV to production only for production builds' do
      jekyll_build = step_named('jekyll build')
      expect(jekyll_build.dig('env', 'JEKYLL_ENV')).to eq("${{ inputs.production && 'production' || 'development' }}")
    end

    it 'removes the (real, LFS-resolved) remix-kit archives from the site before upload in production' do
      cleanup = step_named('remove remix-kit archives from production site')
      expect(cleanup).not_to be_nil
      expect(cleanup['if']).to eq('${{ inputs.production }}')
      expect(cleanup['run']).to include('_site/assets/remix-kits')

      upload_index = steps.index { |step| step['uses'] == 'actions/upload-artifact@v7' }
      cleanup_index = steps.index(cleanup)
      expect(cleanup_index).to be < upload_index
    end
  end

  describe '.github/workflows/publish.yml' do
    let(:workflow) { load_workflow('publish.yml') }

    it 'requests a production build so LFS binaries are linked, not embedded' do
      expect(workflow['jobs']['build'].dig('with', 'production')).to be(true)
    end

    it 'checks out real Git LFS content for the publish job' do
      publish_steps = workflow['jobs']['publish']['steps']
      checkout = publish_steps.find { |step| step['uses'] == 'actions/checkout@v7' }
      expect(checkout.dig('with', 'lfs')).to be(true)
    end

    it 'copies cover images into _site preserving their directory structure' do
      publish_steps = workflow['jobs']['publish']['steps']
      copy_step = publish_steps.find { |step| step['name'] == 'copy git lfs cover images into _site' }
      expect(copy_step).not_to be_nil
      expect(copy_step['run']).to include('assets/images/covers/')
      expect(copy_step['run']).to include('mkdir -p')
      expect(copy_step['run']).not_to include('remix-kits')
    end

    it 'no longer flattens Git LFS files into the site root with a bare mv' do
      publish_steps = workflow['jobs']['publish']['steps']
      expect(publish_steps).not_to include(a_hash_including('run' => a_string_matching(/mv \$\(git lfs ls-files/)))
    end
  end
end

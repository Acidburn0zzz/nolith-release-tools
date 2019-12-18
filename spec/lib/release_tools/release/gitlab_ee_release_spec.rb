# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Release::GitlabEeRelease do
  include RuggedMatchers

  # Fixtures are copied from CE spec

  let(:repo_path)    { File.join(Dir.tmpdir, ReleaseFixture.repository_name) }
  let(:ob_repo_path) { File.join(Dir.tmpdir, OmnibusReleaseFixture.repository_name) }
  let(:repository)    { Rugged::Repository.new(repo_path) }
  let(:ob_repository) { Rugged::Repository.new(ob_repo_path) }
  let(:security_release) { false }

  before do
    cleanup!

    fixture    = ReleaseFixture.new
    ob_fixture = OmnibusReleaseFixture.new

    enable_feature(:security_remote)
    allow(ReleaseTools::SharedStatus).to receive(:security_release?)
      .and_return(security_release)

    fixture.rebuild_fixture!
    ob_fixture.rebuild_fixture!

    allow_any_instance_of(ReleaseTools::RemoteRepository)
      .to receive(:cleanup)
      .and_return(true)

    allow_any_instance_of(described_class).to receive(:remotes)
      .and_return(canonical: "file://#{fixture.fixture_path}")

    allow_any_instance_of(ReleaseTools::Release::OmnibusGitlabRelease).to receive(:remotes)
      .and_return(canonical: "file://#{ob_fixture.fixture_path}")
  end

  after do
    cleanup!
  end

  def cleanup!
    FileUtils.rm_rf(repo_path,    secure: true) if File.exist?(repo_path)
    FileUtils.rm_rf(ob_repo_path, secure: true) if File.exist?(ob_repo_path)
  end

  def execute(version, branch)
    cng_spy = spy
    stub_const('ReleaseTools::Release::CNGImageRelease', cng_spy)

    described_class.new(version).execute

    expect(cng_spy).to have_received(:execute)

    repository.checkout(branch)
    ob_repository.checkout(branch)
  end

  describe '#execute' do
    let(:changelog_manager) { double(release: true) }
    let(:ob_changelog_manager) { double(release: true) }

    before do
      allow(ReleaseTools::Changelog::Manager).to receive(:new).with(repo_path).and_return(changelog_manager)
      allow(ReleaseTools::Changelog::Manager).to receive(:new).with(ob_repo_path, 'CHANGELOG.md').and_return(ob_changelog_manager)
    end

    context 'UBI-based CNG images' do
      let(:version) { "9.1.24-ee" }

      it 'triggers CNG release for both standard and UBI-based CNG images' do
        cng_spy = spy
        stub_const('ReleaseTools::Release::CNGImageRelease', cng_spy)

        described_class.new(version).execute

        expect(cng_spy).to have_received(:execute).twice
      end
    end
  end
end

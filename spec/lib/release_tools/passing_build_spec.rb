# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::PassingBuild do
  let(:project) { ReleaseTools::Project::GitlabCe }
  let(:fake_commit) { double('Commit', id: SecureRandom.hex(20), created_at: Time.now.to_s) }
  let(:version_map) { { 'VERSION' => '1.2.3' } }

  subject(:service) { described_class.new(project, 'master') }

  describe '#execute' do
    let(:fake_commits) { spy }

    before do
      stub_const('ReleaseTools::Commits', fake_commits)
    end

    it 'raises an error without a dev commit' do
      expect(fake_commits).to receive(:latest_dev_green_build_commit)
        .and_return(nil)

      expect { service.execute(nil) }
        .to raise_error(/Unable to find a passing/)
    end

    it 'fetches component versions' do
      expect(fake_commits).to receive(:latest_dev_green_build_commit)
        .and_return(fake_commit)

      expect(ReleaseTools::ComponentVersions)
        .to receive(:get).with(project, fake_commit.id)
        .and_return(version_map)

      expect(service).not_to receive(:trigger_build)

      service.execute(double(trigger_build: false))
    end

    it 'triggers a build when specified' do
      expect(fake_commits).to receive(:latest_dev_green_build_commit)
        .and_return(fake_commit)

      expect(ReleaseTools::ComponentVersions)
        .to receive(:get).with(project, fake_commit.id)
        .and_return(version_map)

      expect(service).to receive(:trigger_build)

      service.execute(double(trigger_build: true))
    end
  end

  describe '#trigger_build' do
    let(:fake_client) { spy }
    let(:fake_ops_client) { spy }
    let(:project) { ReleaseTools::Project::GitlabCe }
    let(:version_map) { { 'VERSION' => '1.2.3' } }

    before do
      # Normally this gets set by `execute`, but we're bypassing that in specs
      service.instance_variable_set(:@version_map, version_map)
    end

    context 'when using auto-deploy' do
      let(:tag_name) { 'tag-name' }

      subject(:service) { described_class.new(project, '11-10-auto-deploy-1234') }

      before do
        allow(ReleaseTools::AutoDeploy::Naming).to receive(:tag)
          .and_return(tag_name)

        stub_const('ReleaseTools::GitlabClient', fake_client)
        stub_const('ReleaseTools::GitlabOpsClient', fake_ops_client)
      end

      context 'with component changes' do
        before do
          allow(ReleaseTools::ComponentVersions)
            .to receive(:omnibus_version_changes?).and_return(true)
        end

        it 'updates Omnibus versions and tags' do
          expect(ReleaseTools::ComponentVersions)
            .to receive(:update_omnibus).with('11-10-auto-deploy-1234', version_map)
            .and_return(fake_commit)

          expect(service).to receive(:tag).with(fake_commit)

          service.trigger_build
        end
      end

      context 'with Omnibus changes' do
        before do
          allow(ReleaseTools::ComponentVersions)
            .to receive(:omnibus_version_changes?).and_return(false)

          allow(service).to receive(:omnibus_changes?).and_return(true)
        end

        it 'tags' do
          stub_const('ReleaseTools::Commits', spy(latest: fake_commit))
          expect(ReleaseTools::Commits)
            .to receive(:new).with(ReleaseTools::Project::OmnibusGitlab, ref: '11-10-auto-deploy-1234')

          expect(service).to receive(:tag).with(fake_commit)

          service.trigger_build
        end
      end

      context 'with no changes' do
        before do
          allow(ReleaseTools::ComponentVersions)
            .to receive(:omnibus_version_changes?).and_return(false)
          allow(service).to receive(:omnibus_changes?).and_return(false)
        end

        it 'does nothing' do
          expect(service).not_to receive(:tag)

          service.trigger_build
        end
      end
    end

    context 'when not using auto-deploy' do
      subject(:service) { described_class.new(project, 'master') }

      it 'triggers a pipeline build' do
        ClimateControl.modify(CI_PIPELINE_ID: '1234', OMNIBUS_BUILD_TRIGGER_TOKEN: 'token') do
          expect(ReleaseTools::GitlabDevClient)
            .to receive(:create_branch).with("master-1234", 'master', project)
          expect(ReleaseTools::Pipeline)
            .to receive(:new).with(project, 'master', version_map)
            .and_return(double(trigger: true))
          expect(ReleaseTools::GitlabDevClient)
            .to receive(:delete_branch).with("master-1234", project)

          VCR.use_cassette('pipeline/trigger') do
            service.trigger_build
          end
        end
      end
    end
  end

  describe '#tag' do
    let(:fake_client) { spy }
    let(:fake_ops_client) { spy }
    let(:tag_name) { 'tag-name' }

    before do
      allow(ReleaseTools::AutoDeploy::Naming).to receive(:tag)
        .and_return(tag_name)

      service.instance_variable_set(:@version_map, version_map)

      stub_const('ReleaseTools::GitlabClient', fake_client)
      stub_const('ReleaseTools::GitlabOpsClient', fake_ops_client)
    end

    it 'tags Omnibus with an annotated tag' do
      expect(service).to receive(:tag_omnibus)
        .with(tag_name, anything, fake_commit)
        .and_call_original

      service.tag(fake_commit)

      expect(fake_client)
        .to have_received(:create_tag)
        .with(
          fake_client.project_path(project),
          tag_name,
          fake_commit.id,
          "Auto-deploy tag-name\n\nVERSION: 1.2.3"
        )
    end

    it 'tags Deployer with an annotated tag' do
      expect(service).to receive(:tag_deployer)
        .with(tag_name, anything, "master")
        .and_call_original

      service.tag(fake_commit)

      expect(fake_ops_client)
        .to have_received(:create_tag)
        .with(
          ReleaseTools::Project::Deployer.path,
          tag_name,
          "master",
          "Auto-deploy tag-name\n\nVERSION: 1.2.3"
        )
    end
  end
end

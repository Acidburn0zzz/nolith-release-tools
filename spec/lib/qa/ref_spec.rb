require 'spec_helper'

require 'qa/ref'

describe Qa::Ref do
  let(:stable_branch_ref) { '10-0-stable' }
  let(:release_tag_ref) { 'v10.0.0' }
  let(:rc_tag_ref) { 'v10.0.0-rc1' }

  context '#for_project' do
    context 'for ee' do
      let(:project) { Project::GitlabEe }

      it 'outputs the stable branch ref' do
        ref = described_class.new(stable_branch_ref)

        expect(ref.for_project(project)).to eq('10-0-stable-ee')
      end

      it 'outputs the release tag ref' do
        ref = described_class.new(release_tag_ref)

        expect(ref.for_project(project)).to eq('v10.0.0-ee')
      end

      it 'outputs the rc tag ref' do
        ref = described_class.new(rc_tag_ref)

        expect(ref.for_project(project)).to eq('v10.0.0-rc1-ee')
      end

      it 'outputs the correct alternate branch ref' do
        ref = described_class.new('branch')

        expect(ref.for_project(project)).to eq('branch')
      end

      it 'outputs the correct master branch ref' do
        ref = described_class.new('master')

        expect(ref.for_project(project)).to eq('master')
      end
    end

    context 'for ce' do
      let(:project) { Project::GitlabCe }

      it 'outputs the stable branch ref' do
        ref = described_class.new(stable_branch_ref)

        expect(ref.for_project(project)).to eq('10-0-stable')
      end

      it 'outputs the release tag ref' do
        ref = described_class.new(release_tag_ref)

        expect(ref.for_project(project)).to eq('v10.0.0')
      end

      it 'outputs the rc tag ref' do
        ref = described_class.new(rc_tag_ref)

        expect(ref.for_project(project)).to eq('v10.0.0-rc1')
      end

      it 'outputs the correct alternate branch ref' do
        ref = described_class.new('branch')

        expect(ref.for_project(project)).to eq('branch')
      end

      it 'outputs the correct master branch ref' do
        ref = described_class.new('master')

        expect(ref.for_project(project)).to eq('master')
      end
    end
  end
end

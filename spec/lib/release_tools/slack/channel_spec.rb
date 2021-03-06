# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Slack::Channel do
  let(:monthly_release) { ReleaseTools::Version.new('1.2.0') }
  let(:channel) { '#f_release_1_2' }

  describe '.for' do
    it 'returns the correct channel' do
      expect(described_class.for(monthly_release)).to eq channel
    end

    it 'ignores patch version' do
      patch = monthly_release.next_patch

      expect(described_class.for(patch)).to eq channel
    end
  end
end

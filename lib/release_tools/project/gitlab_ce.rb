# frozen_string_literal: true

module ReleaseTools
  module Project
    class GitlabCe < BaseProject
      REMOTES = {
        canonical: 'git@gitlab.com:gitlab-org/gitlab-foss.git',
        dev:       'git@dev.gitlab.org:gitlab/gitlabhq.git'
      }.freeze
    end
  end
end

# frozen_string_literal: true

module ReleaseTools
  class Commits
    include ::SemanticLogger::Loggable

    MAX_COMMITS_TO_CHECK = 100

    attr_reader :project

    def initialize(project, ref: 'master', client: ReleaseTools::GitlabClient)
      @project = project
      @ref = ref

      @client =
        if SharedStatus.security_release?
          # For security releases, we only work on dev
          ReleaseTools::GitlabDevClient
        else
          client
        end
    end

    # Get the latest commit for `ref`
    def latest
      commit_list.first
    end

    def latest_successful
      commit_list.detect(&method(:success?))
    end

    # Find a commit with a passing build on production that also exists on dev
    def latest_dev_green_build_commit
      commit_list.detect do |commit|
        next unless success?(commit)

        begin
          # Hit the dev API with the specified commit to see if it even exists
          ReleaseTools::GitlabDevClient.commit(project, ref: commit.id)
        rescue Gitlab::Error::Error
          logger.debug(
            'Commit passed on production, missing on dev',
            project: project.to_s,
            commit: commit.id
          )

          false
        end
      end
    end

    private

    def commit_list
      @commit_list ||= @client.commits(
        @project,
        per_page: MAX_COMMITS_TO_CHECK,
        ref_name: @ref
      )
    end

    def success?(commit)
      result = @client.commit(@project, ref: commit.id)

      return false if result.status != 'success'
      return true if @project != ReleaseTools::Project::GitlabEe

      # Prevent false positive on docs-only pipelines
      #
      # A gitlab full pipeline has over 200 jobs, but isn't necessarily consistent
      # about the order, so we're only checking size
      @client
        .pipeline_jobs(@project, result.last_pipeline.id, per_page: 50)
        .has_next_page?
    end
  end
end

# frozen_string_literal: true

require_relative '../support/ubi_helper'

module ReleaseTools
  module Services
    class SyncRemotesService
      include ::SemanticLogger::Loggable

      def initialize(version)
        @version = version.to_ce
        @omnibus = OmnibusGitlabVersion.new(@version.to_omnibus)
      end

      def execute
        if Feature.disabled?(:publish_git)
          logger.warn('The `publish_git` feature is disabled.')
          return
        end

        sync_branches(Project::GitlabEe, @version.stable_branch(ee: true))
        sync_branches(Project::GitlabCe, @version.stable_branch(ee: false))
        sync_branches(Project::OmnibusGitlab, *[
          @omnibus.to_ee.stable_branch, @omnibus.to_ce.stable_branch
        ].uniq) # Omnibus uses a single branch post-12.2

        # There's no need for a separate CNG UBI stable branch. It is the same as EE branch.
        sync_branches(Project::CNGImage, @version.to_ce.stable_branch, @version.to_ee.stable_branch)

        sync_tags(Project::GitlabEe, @version.tag(ee: true))
        sync_tags(Project::GitlabCe, @version.tag(ee: false))
        sync_tags(Project::OmnibusGitlab, @omnibus.to_ee.tag, @omnibus.to_ce.tag)
        sync_tags(Project::CNGImage, @version.to_ce.tag, @version.to_ee.tag, ubi_tag(@version.to_ee))
      end

      # Sync project stable branches across all remotes.
      #
      # If security_remote is enabled it uses all the project remotes
      # (Canonical, Dev and Security), if not it only uses Canonical and Dev.
      #
      # Iterates over stable branches and for each of them:
      # 1. It clones from Canonical.
      # 2. Fetches stable branch from Dev
      # 3. Merges Dev stable branch into Canonical
      # 4. If the merge is successful pushes the changes to all remotes.
      def sync_branches(project, *branches)
        sync_remotes = remotes_to_sync(project).fetch(:remotes)
        remotes_size = remotes_to_sync(project).fetch(:size)

        if sync_remotes.size < remotes_size
          logger.fatal("Expected at least #{remotes_size} remotes, got #{sync_remotes.size}", project: project, remotes: sync_remotes)
          return
        end

        branches.each do |branch|
          repository = RemoteRepository.get(sync_remotes, global_depth: 50, branch: branch)

          repository.fetch(branch, remote: :dev)

          result = repository.merge("dev/#{branch}", branch, no_ff: true)

          if result.status.success?
            logger.info('Pushing branch to remotes', project: project, name: branch, remotes: sync_remotes.keys)
            repository.push_to_all_remotes(branch)
          else
            logger.fatal('Failed to sync branch', project: project, name: branch, output: result.output)
          end
        end
      end

      def sync_tags(project, *tags)
        sync_remotes = remotes_to_sync(project).fetch(:remotes)
        repository = RemoteRepository.get(sync_remotes, global_depth: 1)

        tags.each do |tag|
          logger.info('Fetching tag', project: project, name: tag)
          repository.fetch("refs/tags/#{tag}", remote: :dev)

          logger.info('Pushing tag to remotes', project: project, name: tag, remotes: sync_remotes.keys)
          repository.push_to_all_remotes(tag)
        end
      end

      private

      def remotes_to_sync(project)
        if Feature.enabled?(:security_remote)
          { remotes: project::REMOTES.slice(:canonical, :dev, :security), size: 3 }
        else
          { remotes: project.remotes.slice(:canonical, :dev), size: 2 }
        end
      end
    end
  end
end

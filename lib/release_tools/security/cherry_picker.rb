# frozen_string_literal: true

module ReleaseTools
  module Security
    # Cherry-pick security merge requests from `master` into the current
    # auto-deploy branch.
    class CherryPicker
      include ::SemanticLogger::Loggable

      attr_reader :merge_requests

      def initialize(merge_requests)
        @merge_requests = merge_requests
        @client = Client.new
        @target = ReleaseTools::AutoDeployBranch.current
      end

      def execute
        return unless Feature.enabled?(:security_cherry_picker)

        filter_by_branch!

        @merge_requests.each do |merge_request|
          @client.cherry_pick_commit(
            merge_request.project_id,
            merge_request.merge_commit_sha,
            @target
          )

          logger.info(
            'Cherry-picked security merge request to auto-deploy',
            project: merge_request.project_id,
            merge_request: merge_request.web_url,
            target: @target
          )
        rescue ::Gitlab::Error::BadRequest => ex
          logger.fatal(
            'Failed security cherry-pick to auto-deploy',
            project: merge_request.project_id,
            merge_request: merge_request.web_url,
            target: @target,
            error: ex.message
          )
        end
      end

      private

      # Remove merge requests belonging to a project with no auto-deploy branch
      def filter_by_branch!
        projects = @merge_requests.collect(&:project_id).uniq

        projects.select! do |project_id|
          @client.branch(project_id, @target)
        rescue ::Gitlab::Error::NotFound
          false
        end

        @merge_requests.select! { |mr| projects.include?(mr.project_id) }
      end
    end
  end
end

require_relative 'issue'
require_relative 'regression_issue'
require_relative 'omnibus_gitlab_version'

class PatchIssue < Issue
  def omnibus_version
    @omnibus_version ||= OmnibusGitLabVersion.new(version.to_omnibus(ee: version.ee?))
  end

  def title
    "Release #{version.to_patch}"
  end

  def labels
    'Release'
  end

  def regression_issue
    @regression_issue ||= RegressionIssue.new(version: version)
  end

  protected

  def template_path
    File.expand_path('../templates/patch.md.erb', __dir__)
  end
end

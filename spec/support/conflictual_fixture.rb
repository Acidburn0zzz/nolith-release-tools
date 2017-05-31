require 'fileutils'
require 'rugged'

require_relative 'repository_fixture'

class ConflictualFixture
  include RepositoryFixture

  def self.repository_name
    'conflictual'
  end

  def build_fixture(options = {})
    commit_blob(
      path:    'CONTRIBUTING.md',
      content: 'Sample CONTRIBUTING.md',
      message: 'Add a sample CONTRIBUTING.md',
      author: options[:author]
    )

    commit_blob(
      path:    'README.md',
      content: 'Sample README.md',
      message: 'Add a sample README.md',
      author: options[:author]
    )
  end

  def unique_update_to_file!(file, commit_options = {})
    commit_blob(
      path:    file,
      content: "Content of #{file} in #{fixture_path} is #{SecureRandom.hex}",
      message: "Unique change to #{file}",
      author: commit_options[:author]
    )
  end
end

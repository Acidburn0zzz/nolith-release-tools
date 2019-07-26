# frozen_string_literal: true

require 'version_sorter'

module ReleaseTools
  # Utility methods for dealing with version numbers and version.gitlab.com
  class Versions
    def self.current
      ReleaseTools::VersionClient
        .versions
        .collect(&:version)
    end

    # Given an Array of version numbers, return the next patch versions
    #
    # Example:
    #
    #   next(['1.0.0', '1.1.0', '1.1.1', '1.2.3'])
    #   => ['1.0.1', '1.1.1', '1.1.2', '1.2.4']
    def self.next(versions)
      versions.map do |version|
        ReleaseTools::Version.new(version).next_patch
      end
    end

    # Given an Array of version strings, find the three latest by minor number
    #
    # Example:
    #
    #   latest(['1.0.0', '1.1.0', '1.1.1', '1.2.3'], 3)
    #   => ['1.2.3', '1.1.1', '1.0.0']
    def self.latest(versions, count = 3)
      ::VersionSorter.rsort(versions).uniq do |version|
        version.split('.').take(2)
      end.take(count)
    end

    # Get the next three security patch versions
    def self.next_security_versions
      self.next(latest(current, 3))
    end
  end
end

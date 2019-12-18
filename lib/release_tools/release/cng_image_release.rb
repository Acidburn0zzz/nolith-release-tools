# frozen_string_literal: true

require_relative '../support/ubi_helper'

module ReleaseTools
  module Release
    class CNGImageRelease < BaseRelease
      class VersionFileDoesNotExistError < StandardError; end
      class VersionNotFoundError < StandardError; end
      def remotes
        Project::CNGImage.remotes
      end

      def version_string_from_gemfile(gem_name)
        gem_file = File.join(options[:gitlab_repo_path], 'Gemfile.lock')

        ensure_version_file_exists!(gem_file)

        lock_parser = Bundler::LockfileParser.new(Bundler.read_file(gem_file))
        spec = lock_parser.specs.find { |x| x.name == gem_name.to_s }

        raise VersionNotFoundError.new("Unable to find version for gem `#{gem_name}`") if spec.nil?

        version = spec.version.to_s

        logger.trace("#{gem_name} version", version: version)

        version
      end

      def tag
        options[:ubi] && ubi?(version) ? ubi_tag(version, options[:ubi_version] || '8') : super
      end

      private

      def bump_versions
        logger.trace('bump versions')
        target_file = File.join(repository.path, 'ci_files/variables.yml')

        yaml_contents = YAML.load_file(target_file)
        yaml_contents['variables'].merge!(component_versions)

        File.open(target_file, 'w') do |f|
          f.write(YAML.dump(yaml_contents))
        end

        repository.commit(target_file, message: "Update #{target_file} for #{version}")
      end

      def component_versions
        components = {}

        # These components always track the GitLab release version
        %w[
          GITLAB_VERSION
          GITLAB_REF_SLUG
          GITLAB_ASSETS_TAG
        ].each { |key| components[key] = version_string(version) }

        # These components specify their versions independently
        %w[
          GITALY_SERVER_VERSION
          GITLAB_ELASTICSEARCH_INDEXER_VERSION
          GITLAB_SHELL_VERSION
          GITLAB_WORKHORSE_VERSION
        ].each { |key| components[key] = version_string_from_file(key) }

        # These components specify their versions inside the Gemfile
        {
          mail_room: "MAILROOM_VERSION"
        }
        .each { |key, value| components[value] = version_string_from_gemfile(key) }

        logger.trace('components', components: components)

        components
      end

      def version_string(version)
        # Prepend 'v' if version is semver
        return "v#{version}" if /^\d+\.\d+\.\d+(-rc\d+)?(-ee)?$/.match?(version)

        version
      end

      def read_file_from_gitlab_repo(file_name)
        logger.trace('reading file', file: file_name)
        gitlab_file_path = File.join(options[:gitlab_repo_path], file_name)
        ensure_version_file_exists!(gitlab_file_path)

        File.read(gitlab_file_path).strip
      end

      def version_string_from_file(file_name)
        version_string(read_file_from_gitlab_repo(file_name))
      end

      def ensure_version_file_exists!(filename)
        raise VersionFileDoesNotExistError.new(filename) unless File.exist?(filename)
      end
    end
  end
end

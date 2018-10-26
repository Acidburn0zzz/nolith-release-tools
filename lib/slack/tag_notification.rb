module Slack
  class TagNotification < Webhook
    def self.webhook_url
      # NOTE: We return an empty String here rather than bubbling up to the
      # parent implementation. If a release manager doesn't set this in their
      # environment, it's fine to just skip the notification silently.
      ENV.fetch('SLACK_TAG_URL', '')
    end

    def self.release(version)
      text = "_#{SharedStatus.user}_ tagged `#{version}`".tap do |str|
        str << " as a security release" if SharedStatus.security_release?
      end

      fire_hook(text: text)
    end
  end
end

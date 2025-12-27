module DeployAssist
  class AppDetector
    def app_name
      # Try to detect from Rails application
      Rails.application.class.module_parent_name.underscore.dasherize
    end

    def domain
      # Try to detect from routes or environment
      if Rails.env.production?
        ENV['APP_DOMAIN'] || ENV['HOST'] || 'yourapp.com'
      else
        'localhost:3000'
      end
    end

    def environment
      Rails.env.to_s
    end

    def repository_url
      # Try to detect from git remote
      `git remote get-url origin 2>/dev/null`.strip rescue nil
    end
  end
end

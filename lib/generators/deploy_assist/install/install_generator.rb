module DeployAssist
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc "Installs DeployAssist engine"

      def copy_initializer
        template "deploy_assist.rb", "config/initializers/deploy_assist.rb"
      end

      def install_migrations
        rake "deploy_assist:install:migrations"
      end

      def mount_engine
        route "mount DeployAssist::Engine, at: '/admin/deploy_setup'"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end

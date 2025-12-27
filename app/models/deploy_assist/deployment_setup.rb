module DeployAssist
  class DeploymentSetup < ApplicationRecord
    belongs_to :user
    has_many :service_configurations, dependent: :destroy
    has_many :credentials, dependent: :destroy

    enum :setup_status, { pending: 0, in_progress: 1, completed: 2 }

    validates :environment, presence: true

    before_validation :detect_app_info, on: :create

    def setup_progress_percentage
      return 0 if service_configurations.none?
      (service_configurations.completed.count.to_f / service_configurations.count * 100).round
    end

    def app_display_name
      app_name.presence || Rails.application.class.module_parent_name
    end

    private

    def detect_app_info
      detector = DeployAssist::AppDetector.new
      self.app_name ||= detector.app_name
      self.domain ||= detector.domain
    end
  end
end

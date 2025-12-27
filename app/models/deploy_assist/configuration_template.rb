module DeployAssist
  class ConfigurationTemplate < ApplicationRecord
    belongs_to :user

    enum :service_type, {
      aws_deployment: 0,
      google_oauth: 1,
      aws_ses: 2,
      stripe: 3
    }

    validates :name, :service_type, presence: true

    scope :public_templates, -> { where(public: true) }
    scope :for_service, ->(service_type) { where(service_type: service_type) }

    before_save :increment_usage_count, if: :will_save_change_to_usage_count?

    private

    def increment_usage_count
      self.usage_count ||= 0
    end
  end
end

module DeployAssist
  class ServiceConfiguration < ApplicationRecord
    belongs_to :deployment_setup
    has_many :wizard_steps, dependent: :destroy
    has_many :automation_tasks, dependent: :destroy
    has_many :instructions, dependent: :destroy

    enum :service_type, {
      aws_deployment: 0,
      google_oauth: 1,
      aws_ses: 2,
      stripe: 3,
      chrome_extension: 4
    }

    enum :status, {
      not_started: 0,
      collecting_info: 1,
      in_progress: 2,
      completed: 3,
      failed: 4
    }

    validates :deployment_setup, :service_type, presence: true

    scope :completed, -> { where(status: :completed) }
    scope :in_progress, -> { where(status: [:collecting_info, :in_progress]) }
  end
end

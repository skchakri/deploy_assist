module DeployAssist
  class WizardStep < ApplicationRecord
    belongs_to :service_configuration

    enum :status, {
      pending: 0,
      in_progress: 1,
      completed: 2,
      skipped: 3
    }

    validates :step_key, :step_number, presence: true

    scope :completed, -> { where(status: :completed) }
    scope :pending, -> { where(status: :pending) }
  end
end

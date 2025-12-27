module DeployAssist
  class AutomationTask < ApplicationRecord
    belongs_to :service_configuration

    enum :status, {
      pending: 0,
      running: 1,
      completed: 2,
      failed: 3
    }

    validates :task_type, presence: true

    scope :completed, -> { where(status: :completed) }
    scope :failed, -> { where(status: :failed) }
  end
end

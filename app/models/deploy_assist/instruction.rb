module DeployAssist
  class Instruction < ApplicationRecord
    belongs_to :service_configuration

    validates :step_number, :title, presence: true

    scope :ordered, -> { order(step_number: :asc) }
    scope :incomplete, -> { where(completed: false) }

    def mark_complete!
      update!(completed: true, completed_at: Time.current)
    end
  end
end

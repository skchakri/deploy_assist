module DeployAssist
  class Credential < ApplicationRecord
    belongs_to :deployment_setup

    encrypts :encrypted_value, deterministic: false

    validates :service, :credential_type, :encrypted_value, presence: true

    scope :active, -> { where(active: true) }
    scope :for_service, ->(service) { where(service: service) }

    def masked_value
      return nil unless key_identifier.present?
      "#{key_identifier[0..7]}...#{key_identifier[-4..]}"
    end
  end
end

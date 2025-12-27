require "deploy_assist/version"
require "deploy_assist/engine"

module DeployAssist
  # Configuration
  mattr_accessor :aws_regions, default: ['us-east-1', 'us-west-2', 'eu-west-1']
  mattr_accessor :default_region, default: 'us-east-1'
  mattr_accessor :require_admin, default: true

  def self.configure
    yield self
  end
end

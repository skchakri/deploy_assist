DeployAssist.configure do |config|
  # AWS regions to support
  config.aws_regions = ['us-east-1', 'us-west-2', 'eu-west-1']

  # Default AWS region
  config.default_region = 'us-east-1'

  # Require admin access (set to false to allow all authenticated users)
  config.require_admin = true
end

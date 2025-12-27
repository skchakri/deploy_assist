require 'aws-sdk-iam'

module DeployAssist
  module Automation
    module Aws
      class IamService
        attr_reader :client

        def initialize(access_key_id, secret_access_key, region = 'us-east-1')
          @client = ::Aws::IAM::Client.new(
            access_key_id: access_key_id,
            secret_access_key: secret_access_key,
            region: region
          )
        end

        def create_deployment_user(app_name)
          username = "#{app_name}-deploy"

          # Create IAM user
          user_response = @client.create_user(user_name: username)

          # Attach necessary policies
          attach_policies(username)

          # Create access key
          key_response = @client.create_access_key(user_name: username)

          {
            success: true,
            username: username,
            user_arn: user_response.user.arn,
            access_key_id: key_response.access_key.access_key_id,
            secret_access_key: key_response.access_key.secret_access_key
          }
        rescue ::Aws::IAM::Errors::ServiceError => e
          {
            success: false,
            error: e.message,
            error_code: e.code
          }
        end

        private

        def attach_policies(username)
          # Attach managed policies for common deployment needs
          policies = [
            'arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess',
            'arn:aws:iam::aws:policy/AmazonS3FullAccess',
            'arn:aws:iam::aws:policy/AmazonRDSFullAccess'
          ]

          policies.each do |policy_arn|
            @client.attach_user_policy(
              user_name: username,
              policy_arn: policy_arn
            )
          end
        end
      end
    end
  end
end

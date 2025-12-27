require 'aws-sdk-s3'

module DeployAssist
  module Automation
    module Aws
      class S3Service
        attr_reader :client

        def initialize(access_key_id, secret_access_key, region)
          @client = ::Aws::S3::Client.new(
            access_key_id: access_key_id,
            secret_access_key: secret_access_key,
            region: region
          )
          @region = region
        end

        def create_storage_bucket(app_name, environment = 'production')
          bucket_name = "#{app_name}-#{environment}-storage"

          # Create bucket
          create_bucket_config = {}
          # us-east-1 doesn't need location constraint
          unless @region == 'us-east-1'
            create_bucket_config[:create_bucket_configuration] = {
              location_constraint: @region
            }
          end

          @client.create_bucket(
            bucket: bucket_name,
            **create_bucket_config
          )

          # Enable versioning
          @client.put_bucket_versioning(
            bucket: bucket_name,
            versioning_configuration: { status: 'Enabled' }
          )

          # Set CORS for Active Storage
          @client.put_bucket_cors(
            bucket: bucket_name,
            cors_configuration: {
              cors_rules: [{
                allowed_methods: ['GET', 'PUT', 'POST', 'DELETE'],
                allowed_origins: ['*'],
                allowed_headers: ['*'],
                max_age_seconds: 3000
              }]
            }
          )

          # Enable server-side encryption
          @client.put_bucket_encryption(
            bucket: bucket_name,
            server_side_encryption_configuration: {
              rules: [{
                apply_server_side_encryption_by_default: {
                  sse_algorithm: 'AES256'
                }
              }]
            }
          )

          {
            success: true,
            bucket_name: bucket_name,
            region: @region,
            url: "s3://#{bucket_name}"
          }
        rescue ::Aws::S3::Errors::ServiceError => e
          {
            success: false,
            error: e.message,
            error_code: e.code
          }
        end
      end
    end
  end
end

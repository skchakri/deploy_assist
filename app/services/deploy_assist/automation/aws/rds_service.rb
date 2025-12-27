require 'aws-sdk-rds'

module DeployAssist
  module Automation
    module Aws
      class RdsService
        attr_reader :client

        def initialize(access_key_id, secret_access_key, region)
          @client = ::Aws::RDS::Client.new(
            access_key_id: access_key_id,
            secret_access_key: secret_access_key,
            region: region
          )
          @region = region
        end

        def create_database(app_name, config)
          db_instance_identifier = "#{app_name}-#{config[:environment] || 'production'}-db"
          master_password = SecureRandom.alphanumeric(32)

          params = {
            db_instance_identifier: db_instance_identifier,
            db_instance_class: config[:instance_class] || 'db.t3.small',
            engine: 'postgres',
            engine_version: '16.1',
            master_username: config[:master_username] || 'postgres',
            master_user_password: master_password,
            allocated_storage: (config[:storage_gb] || 20).to_i,
            storage_type: 'gp3',
            publicly_accessible: false,
            backup_retention_period: 7,
            multi_az: config[:multi_az] == true || config[:multi_az] == 'true',
            storage_encrypted: true,
            auto_minor_version_upgrade: true,
            preferred_backup_window: '03:00-04:00',
            preferred_maintenance_window: 'sun:04:00-sun:05:00'
          }

          @client.create_db_instance(params)

          # Wait for database to be available (this can take 5-10 minutes)
          # In production, you'd monitor this separately
          Rails.logger.info "Database #{db_instance_identifier} creation initiated"

          # For now, return pending status
          {
            success: true,
            status: 'creating',
            db_instance_identifier: db_instance_identifier,
            master_username: config[:master_username] || 'postgres',
            master_password: master_password,
            message: 'Database creation initiated. This will take 5-10 minutes.'
          }
        rescue ::Aws::RDS::Errors::ServiceError => e
          {
            success: false,
            error: e.message,
            error_code: e.code
          }
        end

        def get_database_status(db_instance_identifier)
          response = @client.describe_db_instances(
            db_instance_identifier: db_instance_identifier
          )

          instance = response.db_instances.first

          if instance.db_instance_status == 'available'
            {
              success: true,
              status: 'available',
              endpoint: instance.endpoint.address,
              port: instance.endpoint.port,
              database_name: instance.db_name || 'postgres'
            }
          else
            {
              success: true,
              status: instance.db_instance_status,
              message: "Database is #{instance.db_instance_status}"
            }
          end
        rescue ::Aws::RDS::Errors::ServiceError => e
          {
            success: false,
            error: e.message
          }
        end
      end
    end
  end
end

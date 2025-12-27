module DeployAssist
  class AutomationExecutionJob < ApplicationJob
    queue_as :default

    def perform(service_configuration_id)
      config = ServiceConfiguration.find(service_configuration_id)
      data = config.collected_data
      setup = config.deployment_setup

      case config.service_type
      when 'aws_deployment'
        execute_aws_deployment(config, data, setup)
      else
        Rails.logger.warn "Unknown service type: #{config.service_type}"
      end
    rescue StandardError => e
      config.update!(
        status: :failed,
        error_message: e.message
      )
      Rails.logger.error "Automation failed: #{e.message}\n#{e.backtrace.join("\n")}"
      raise
    end

    private

    def execute_aws_deployment(config, data, setup)
      results = {}
      aws_creds = {
        access_key_id: data['access_key_id'],
        secret_access_key: data['secret_access_key'],
        region: data['region'] || DeployAssist.default_region
      }

      # Step 1: Create IAM User
      create_automation_task(config, 'create_iam_user', 'Creating IAM deployment user')
      iam_service = Automation::Aws::IamService.new(
        aws_creds[:access_key_id],
        aws_creds[:secret_access_key],
        aws_creds[:region]
      )

      iam_result = iam_service.create_deployment_user(setup.app_name)
      results['iam_user'] = iam_result

      if iam_result[:success]
        complete_automation_task(config, 'create_iam_user', iam_result)

        # Store credentials securely
        store_credential(setup, 'aws_iam', 'access_key_id',
                        iam_result[:access_key_id], iam_result[:access_key_id])
        store_credential(setup, 'aws_iam', 'secret_access_key',
                        iam_result[:secret_access_key], iam_result[:access_key_id])
      else
        fail_automation_task(config, 'create_iam_user', iam_result[:error])
      end

      # Step 2: Create S3 Bucket (if requested)
      if data['create_s3_bucket'] != 'false'
        create_automation_task(config, 'create_s3_bucket', 'Creating S3 storage bucket')
        s3_service = Automation::Aws::S3Service.new(
          aws_creds[:access_key_id],
          aws_creds[:secret_access_key],
          aws_creds[:region]
        )

        bucket_name = data['s3_bucket_name'].presence || "#{setup.app_name}-production-storage"
        s3_result = s3_service.create_storage_bucket(setup.app_name, setup.environment)
        results['s3_bucket'] = s3_result

        if s3_result[:success]
          complete_automation_task(config, 'create_s3_bucket', s3_result)
        else
          fail_automation_task(config, 'create_s3_bucket', s3_result[:error])
        end
      end

      # Step 3: Create RDS Instance
      create_automation_task(config, 'create_rds_instance', 'Creating RDS PostgreSQL database')
      rds_service = Automation::Aws::RdsService.new(
        aws_creds[:access_key_id],
        aws_creds[:secret_access_key],
        aws_creds[:region]
      )

      rds_config = {
        environment: setup.environment,
        instance_class: data['db_instance_class'] || 'db.t3.small',
        storage_gb: data['storage_gb'] || 20,
        multi_az: data['multi_az'] == 'true'
      }

      rds_result = rds_service.create_database(setup.app_name, rds_config)
      results['rds_database'] = rds_result

      if rds_result[:success]
        complete_automation_task(config, 'create_rds_instance', rds_result)

        # Store database password
        store_credential(setup, 'rds', 'master_password',
                        rds_result[:master_password], rds_result[:db_instance_identifier])
      else
        fail_automation_task(config, 'create_rds_instance', rds_result[:error])
      end

      # Update service configuration with results
      config.update!(
        automation_results: results,
        status: :completed,
        completed_at: Time.current
      )
    end

    def create_automation_task(config, task_type, description)
      config.automation_tasks.create!(
        task_type: task_type,
        description: description,
        status: :running,
        executed_at: Time.current
      )
    end

    def complete_automation_task(config, task_type, result)
      task = config.automation_tasks.find_by(task_type: task_type)
      task&.update!(
        status: :completed,
        task_result: result
      )
    end

    def fail_automation_task(config, task_type, error)
      task = config.automation_tasks.find_by(task_type: task_type)
      task&.update!(
        status: :failed,
        error_message: error
      )
    end

    def store_credential(setup, service, credential_type, value, identifier)
      setup.credentials.create!(
        service: service,
        credential_type: credential_type,
        encrypted_value: value,
        key_identifier: identifier
      )
    end
  end
end

module DeployAssist
  module InstructionGenerators
    class AwsDeploymentGenerator
      def initialize(service_configuration)
        @config = service_configuration
        @setup = service_configuration.deployment_setup
        @data = service_configuration.collected_data
        @results = service_configuration.automation_results
      end

      def generate
        [
          create_kamal_config_instruction,
          create_database_yml_instruction,
          create_credentials_instruction,
          create_secrets_file_instruction,
          create_ec2_launch_instruction,
          create_deployment_instruction
        ]
      end

      private

      def create_kamal_config_instruction
        kamal_config = ConfigGenerators::KamalConfigGenerator.new(@setup, @config).generate

        Instruction.create!(
          service_configuration: @config,
          step_number: 1,
          title: "Create Kamal Configuration",
          instruction_type: 'copy_snippet',
          instruction_text: <<~MD,
            ## Create config/deploy.yml

            Copy this configuration to your Rails app at `config/deploy.yml`:

            ```yaml
            #{kamal_config}
            ```

            **Important:** Replace `EC2_PUBLIC_IP_HERE` with your actual EC2 instance IP after launching it.
          MD
          data: { snippet: kamal_config, filename: 'config/deploy.yml' }
        )
      end

      def create_database_yml_instruction
        database_config = ConfigGenerators::DatabaseYmlGenerator.new(@setup, @config).generate

        Instruction.create!(
          service_configuration: @config,
          step_number: 2,
          title: "Update Database Configuration",
          instruction_type: 'copy_snippet',
          instruction_text: <<~MD,
            ## Update config/database.yml

            Replace your `config/database.yml` with this configuration:

            ```yaml
            #{database_config}
            ```

            This includes settings for Solid Cache, Solid Queue, and Solid Cable.
          MD
          data: { snippet: database_config, filename: 'config/database.yml' }
        )
      end

      def create_credentials_instruction
        credentials_config = ConfigGenerators::CredentialsYmlGenerator.new(@setup, @config).generate

        Instruction.create!(
          service_configuration: @config,
          step_number: 3,
          title: "Add Production Credentials",
          instruction_type: 'copy_snippet',
          instruction_text: <<~MD,
            ## Add AWS Credentials

            Run this command:
            ```bash
            EDITOR="code --wait" rails credentials:edit --environment production
            ```

            Then add this configuration:

            ```yaml
            #{credentials_config}
            ```

            Save and close the editor.
          MD
          data: { snippet: credentials_config, filename: 'config/credentials/production.yml.enc' }
        )
      end

      def create_secrets_file_instruction
        db_password = @setup.credentials.find_by(service: 'rds', credential_type: 'master_password')&.encrypted_value || 'YOUR_DB_PASSWORD'

        secrets_content = <<~BASH
          KAMAL_REGISTRY_PASSWORD=YOUR_DOCKER_HUB_ACCESS_TOKEN
          RAILS_MASTER_KEY=$(cat config/credentials/production.key)
          #{@setup.app_name.upcase}_DATABASE_PASSWORD=#{db_password}
        BASH

        Instruction.create!(
          service_configuration: @config,
          step_number: 4,
          title: "Create Kamal Secrets File",
          instruction_type: 'copy_snippet',
          instruction_text: <<~MD,
            ## Create .kamal/secrets

            Create the file `.kamal/secrets` in your project root:

            ```bash
            #{secrets_content}
            ```

            **Important:** Replace `YOUR_DOCKER_HUB_ACCESS_TOKEN` with your Docker Hub access token.

            **Get Docker Hub token:** [https://hub.docker.com/settings/security](https://hub.docker.com/settings/security)
          MD
          data: { snippet: secrets_content, filename: '.kamal/secrets' }
        )
      end

      def create_ec2_launch_instruction
        Instruction.create!(
          service_configuration: @config,
          step_number: 5,
          title: "Launch EC2 Instance",
          instruction_type: 'manual_action',
          instruction_text: <<~MD,
            ## Launch EC2 Instance

            1. Go to [AWS EC2 Console](https://console.aws.amazon.com/ec2/v2/home?region=#{aws_region}#LaunchInstances:)
            2. Choose **Amazon Linux 2023 AMI**
            3. Instance type: **t3.small** or larger
            4. Create a new key pair named `#{@setup.app_name}-key` and download the `.pem` file
            5. Network settings:
               - Allow SSH (port 22)
               - Allow HTTP (port 80)
               - Allow HTTPS (port 443)
            6. Storage: **20 GB gp3** minimum
            7. Launch instance

            **After launch:**
            - Copy the Public IP address
            - Move the `.pem` file to `~/.ssh/#{@setup.app_name}-key.pem`
            - Set permissions: `chmod 400 ~/.ssh/#{@setup.app_name}-key.pem`
            - Update `config/deploy.yml` with the EC2 IP address
          MD
          data: {
            url: "https://console.aws.amazon.com/ec2/v2/home?region=#{aws_region}#LaunchInstances:"
          }
        )
      end

      def create_deployment_instruction
        Instruction.create!(
          service_configuration: @config,
          step_number: 6,
          title: "Deploy with Kamal",
          instruction_type: 'manual_action',
          instruction_text: <<~MD,
            ## Initial Deployment

            Once your EC2 instance is running and Docker is installed:

            ```bash
            # Setup Docker on EC2 (first time only)
            kamal server setup

            # Deploy your application
            kamal deploy
            ```

            **Monitor deployment:**
            ```bash
            kamal app logs
            ```

            **Access your app:**
            - HTTP: `http://YOUR_EC2_IP`
            - HTTPS: `https://#{@setup.domain}` (after DNS is configured)

            **Next steps:**
            1. Point your domain to the EC2 IP address
            2. Kamal will automatically obtain SSL certificate via Let's Encrypt
            3. Run database migrations: `kamal app exec bin/rails db:migrate`
            4. Create admin user: `kamal app exec bin/rails runner "User.create!(email: 'admin@example.com', password: 'password', role: :admin)"`
          MD
          data: {}
        )
      end

      def aws_region
        @data['region'] || DeployAssist.default_region
      end
    end
  end
end

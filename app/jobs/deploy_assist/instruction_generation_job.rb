module DeployAssist
  class InstructionGenerationJob < ApplicationJob
    queue_as :default

    def perform(service_configuration_id)
      config = ServiceConfiguration.find(service_configuration_id)

      case config.service_type
      when 'aws_deployment'
        generate_instructions(config, InstructionGenerators::AwsDeploymentGenerator)
      when 'google_oauth'
        generate_instructions(config, InstructionGenerators::GoogleOauthGenerator)
      when 'aws_ses'
        generate_instructions(config, InstructionGenerators::AwsSesGenerator)
      when 'stripe'
        generate_instructions(config, InstructionGenerators::StripeGenerator)
      when 'chrome_extension'
        generate_instructions(config, InstructionGenerators::ChromeExtensionGenerator)
      else
        Rails.logger.warn "Unknown service type for instruction generation: #{config.service_type}"
      end
    rescue StandardError => e
      Rails.logger.error "Instruction generation failed: #{e.message}"
      raise
    end

    private

    def generate_instructions(config, generator_class)
      generator = generator_class.new(config)
      generator.generate
    end
  end
end

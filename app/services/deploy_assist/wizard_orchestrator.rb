module DeployAssist
  class WizardOrchestrator
    attr_reader :service_configuration

    def initialize(service_configuration)
      @service_configuration = service_configuration
    end

    def current_step
      service_configuration.wizard_steps.find_by(status: [:pending, :in_progress])&.step_number || 1
    end

    def current_step_data
      current_wizard_step = service_configuration.wizard_steps.find_by(step_number: current_step)
      current_wizard_step&.step_data || {}
    end

    def complete_step(step_number, step_data)
      return false if step_data.nil?

      ActiveRecord::Base.transaction do
        # Find or create wizard step
        wizard_step = service_configuration.wizard_steps.find_or_create_by(
          step_number: step_number
        ) do |step|
          step.step_key = step_key_for(step_number)
          step.status = :in_progress
        end

        # Update step data and status
        wizard_step.update!(
          step_data: step_data,
          status: :completed,
          completed_at: Time.current
        )

        # Merge into collected_data
        service_configuration.update!(
          collected_data: service_configuration.collected_data.deep_merge(step_data.to_h),
          completion_percentage: calculate_percentage,
          status: :collecting_info
        )

        # Check if this was the final step
        if step_number >= total_steps
          finalize_wizard
        else
          # Create next step
          service_configuration.wizard_steps.find_or_create_by(step_number: step_number + 1) do |step|
            step.step_key = step_key_for(step_number + 1)
            step.status = :in_progress
          end
        end

        true
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Wizard step completion failed: #{e.message}"
      false
    end

    def finalize_wizard
      service_configuration.update!(status: :in_progress)

      # Enqueue background jobs
      AutomationExecutionJob.perform_later(service_configuration.id)
      InstructionGenerationJob.perform_later(service_configuration.id)
    end

    private

    def total_steps
      case service_configuration.service_type
      when 'aws_deployment' then 4
      when 'google_oauth' then 4
      when 'aws_ses' then 4
      when 'stripe' then 4
      else 4
      end
    end

    def calculate_percentage
      completed_count = service_configuration.wizard_steps.completed.count
      return 0 if total_steps.zero?

      ((completed_count.to_f / total_steps) * 100).round
    end

    def step_key_for(step_number)
      case service_configuration.service_type
      when 'aws_deployment'
        case step_number
        when 1 then 'business_info'
        when 2 then 'aws_credentials'
        when 3 then 'infrastructure'
        when 4 then 'review'
        end
      when 'google_oauth'
        case step_number
        when 1 then 'project_info'
        when 2 then 'consent_screen'
        when 3 then 'credentials'
        when 4 then 'verification'
        end
      else
        "step_#{step_number}"
      end
    end
  end
end

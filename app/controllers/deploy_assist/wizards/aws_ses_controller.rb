module DeployAssist
  module Wizards
    class AwsSesController < ApplicationController
      before_action :load_service_configuration
      before_action :load_orchestrator

      TOTAL_STEPS = 4

      def show
        @step = params[:step_number].to_i
        @step_data = @orchestrator.current_step_data

        render "step_#{@step}"
      end

      def update
        @step = params[:step_number].to_i

        if @orchestrator.complete_step(@step, step_params)
          if @step < TOTAL_STEPS
            redirect_to wizards_aws_ses_step_path(
              config_id: @service_configuration.id,
              step_number: @step + 1
            ), notice: "Step #{@step} completed!"
          else
            redirect_to deploy_assist.instructions_path(config_id: @service_configuration.id),
                        notice: "AWS SES setup guide ready!"
          end
        else
          @step_data = @orchestrator.current_step_data
          flash.now[:alert] = "Please fix the errors below"
          render "step_#{@step}"
        end
      end

      private

      def load_service_configuration
        @service_configuration = ServiceConfiguration.find(params[:config_id])
      end

      def load_orchestrator
        @orchestrator = WizardOrchestrator.new(@service_configuration)
      end

      def step_params
        case params[:step_number].to_i
        when 1
          params.require(:email_config).permit(
            :verification_type,
            :domain,
            :email_address,
            :from_name,
            :from_email
          )
        when 2
          params.require(:aws_credentials).permit(
            :access_key_id,
            :secret_access_key,
            :region
          )
        when 3
          params.require(:configuration).permit(
            :enable_configuration_set,
            :enable_bounce_handling
          )
        when 4
          params.permit(:confirm)
        end
      end
    end
  end
end

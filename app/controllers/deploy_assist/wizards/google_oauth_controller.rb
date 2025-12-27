module DeployAssist
  module Wizards
    class GoogleOauthController < ApplicationController
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
            redirect_to wizards_google_oauth_step_path(
              config_id: @service_configuration.id,
              step_number: @step + 1
            ), notice: "Step #{@step} completed!"
          else
            redirect_to deploy_assist.instructions_path(config_id: @service_configuration.id),
                        notice: "Google OAuth setup guide ready!"
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
          params.require(:project_info).permit(
            :app_name,
            :support_email,
            :developer_contact
          )
        when 2
          params.require(:consent_screen).permit(
            :privacy_policy_url,
            :terms_of_service_url,
            :logo_url,
            scopes: []
          )
        when 3
          params.require(:credentials).permit(
            :redirect_uris,
            :authorized_domains
          )
        when 4
          params.permit(:confirm)
        end
      end
    end
  end
end

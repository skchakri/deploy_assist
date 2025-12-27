module DeployAssist
  module Wizards
    class ChromeExtensionController < ApplicationController
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
            redirect_to wizards_chrome_extension_step_path(
              config_id: @service_configuration.id,
              step_number: @step + 1
            ), notice: "Step #{@step} completed!"
          else
            redirect_to deploy_assist.instructions_path(config_id: @service_configuration.id),
                        notice: "Chrome Extension setup guide ready!"
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
          params.require(:extension_details).permit(
            :extension_name,
            :short_description,
            :detailed_description,
            :category,
            :primary_language,
            :permissions => []
          )
        when 2
          params.require(:store_assets).permit(
            :small_icon_url,
            :large_icon_url,
            :promotional_tile_url,
            :screenshot_urls,
            :demo_video_url
          )
        when 3
          params.require(:privacy_compliance).permit(
            :privacy_policy_url,
            :homepage_url,
            :support_email,
            :permissions_justification,
            :single_purpose_description
          )
        when 4
          params.permit(:confirm)
        end
      end
    end
  end
end

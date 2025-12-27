module DeployAssist
  module Wizards
    class StripeController < ApplicationController
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
            redirect_to wizards_stripe_step_path(
              config_id: @service_configuration.id,
              step_number: @step + 1
            ), notice: "Step #{@step} completed!"
          else
            redirect_to deploy_assist.instructions_path(config_id: @service_configuration.id),
                        notice: "Stripe setup guide ready!"
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
          params.require(:business_details).permit(
            :legal_business_name,
            :country,
            :business_type,
            :business_url,
            :support_email,
            :support_phone
          )
        when 2
          params.require(:products).permit(
            :product_names,
            :price_type,
            :currency,
            :enable_subscriptions
          )
        when 3
          params.require(:webhook_config).permit(
            :webhook_url,
            :enable_webhook_automation,
            :events => []
          )
        when 4
          params.permit(:confirm)
        end
      end
    end
  end
end

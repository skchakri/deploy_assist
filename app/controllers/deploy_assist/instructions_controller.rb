module DeployAssist
  class InstructionsController < ApplicationController
    before_action :load_service_configuration

    def index
      @instructions = @service_configuration.instructions.ordered
    end

    def mark_complete
      instruction = @service_configuration.instructions.find(params[:id])
      instruction.mark_complete!

      redirect_to instructions_path(config_id: @service_configuration.id),
                  notice: "Step marked as complete!"
    end

    private

    def load_service_configuration
      @service_configuration = ServiceConfiguration.find(params[:config_id])
    end
  end
end

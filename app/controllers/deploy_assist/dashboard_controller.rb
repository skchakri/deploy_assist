module DeployAssist
  class DashboardController < ApplicationController
    def index
      @deployment_setups = DeploymentSetup.where(user: current_user).order(created_at: :desc)
      @current_setup = @deployment_setups.find_by(environment: Rails.env) ||
                       @deployment_setups.first
    end
  end
end

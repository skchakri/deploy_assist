module DeployAssist
  class SetupsController < ApplicationController
    before_action :load_deployment_setup, only: [:configure_service, :add_service]

    def index
      @deployment_setups = DeploymentSetup.where(user: current_user).order(created_at: :desc)
    end

    def new
      @deployment_setup = DeploymentSetup.new
    end

    def create
      @deployment_setup = DeploymentSetup.new(setup_params)
      @deployment_setup.user = current_user

      if @deployment_setup.save
        redirect_to deploy_assist.root_path, notice: "Deployment setup created!"
      else
        render :new, alert: "Failed to create setup"
      end
    end

    def show
      @deployment_setup = DeploymentSetup.find(params[:id])
    end

    def configure_service
      service_type = params[:service_type]
      @service_configuration = @deployment_setup.service_configurations.find_or_create_by!(
        service_type: service_type
      )

      redirect_to wizard_path_for(@service_configuration)
    end

    def add_service
      service_type = params[:service_type]

      @service_configuration = @deployment_setup.service_configurations.create!(
        service_type: service_type,
        status: :collecting_info
      )

      redirect_to wizard_path_for(@service_configuration), notice: "Let's configure #{service_type.titleize}!"
    end

    private

    def load_deployment_setup
      @deployment_setup = DeploymentSetup.find(params[:id])
    end

    def setup_params
      params.require(:deployment_setup).permit(:app_name, :environment, :domain, :region)
    end

    def wizard_path_for(service_configuration)
      case service_configuration.service_type
      when 'aws_deployment'
        deploy_assist.wizards_aws_deployment_step_path(config_id: service_configuration.id, step_number: 1)
      when 'google_oauth'
        deploy_assist.wizards_google_oauth_step_path(config_id: service_configuration.id, step_number: 1)
      when 'aws_ses'
        deploy_assist.wizards_aws_ses_step_path(config_id: service_configuration.id, step_number: 1)
      when 'stripe'
        deploy_assist.wizards_stripe_step_path(config_id: service_configuration.id, step_number: 1)
      when 'chrome_extension'
        deploy_assist.wizards_chrome_extension_step_path(config_id: service_configuration.id, step_number: 1)
      else
        deploy_assist.root_path
      end
    end
  end
end

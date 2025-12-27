module DeployAssist
  class ApplicationController < ::ApplicationController
    before_action :authenticate_user!
    before_action :require_admin_access! if DeployAssist.require_admin

    layout "admin"

    private

    def require_admin_access!
      unless current_user.respond_to?(:admin?) && current_user.admin?
        redirect_to main_app.root_path, alert: "Access denied. Admin privileges required."
      end
    end

    def current_deployment_setup
      @current_deployment_setup ||= DeploymentSetup.find(params[:setup_id] || params[:id])
    end
    helper_method :current_deployment_setup
  end
end

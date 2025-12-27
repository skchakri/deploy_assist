module DeployAssist
  module UrlBuilders
    class GoogleConsoleUrlBuilder
      BASE_URL = "https://console.cloud.google.com"

      def initialize(project_id: nil, params: {})
        @project_id = project_id
        @params = params
      end

      def new_project_url
        "#{BASE_URL}/projectcreate"
      end

      def consent_screen_url
        query_params = {
          project: @project_id,
          supportEmail: @params[:support_email],
          applicationName: @params[:app_name]
        }.compact

        url = "#{BASE_URL}/apis/credentials/consent"
        url += "?#{query_params.to_query}" if query_params.any?
        url
      end

      def oauth_credentials_url
        url = "#{BASE_URL}/apis/credentials/oauthclient"
        url += "?project=#{@project_id}" if @project_id.present?
        url
      end

      def api_library_url(api_name = nil)
        url = "#{BASE_URL}/apis/library"
        url += "?project=#{@project_id}" if @project_id.present?
        url += "/#{api_name}" if api_name.present?
        url
      end

      def domain_verification_url
        "https://search.google.com/search-console/welcome"
      end
    end
  end
end

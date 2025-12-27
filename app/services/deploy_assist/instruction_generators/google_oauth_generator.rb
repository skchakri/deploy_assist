module DeployAssist
  module InstructionGenerators
    class GoogleOauthGenerator
      def initialize(service_configuration)
        @config = service_configuration
        @setup = service_configuration.deployment_setup
        @data = service_configuration.collected_data
      end

      def generate
        [
          create_project_instruction,
          configure_consent_screen_instruction,
          create_credentials_instruction,
          add_to_devise_instruction,
          domain_verification_instruction
        ]
      end

      private

      def create_project_instruction
        url_builder = UrlBuilders::GoogleConsoleUrlBuilder.new

        Instruction.create!(
          service_configuration: @config,
          step_number: 1,
          title: "Create Google Cloud Project",
          instruction_type: 'external_link',
          instruction_text: <<~MD,
            ## Create a Google Cloud Project

            1. Go to Google Cloud Console
            2. Click "Create Project"
            3. Project name: **#{@data['app_name']}**
            4. Click "Create"

            **Note:** Copy the Project ID once created (you'll need it for the next steps)
          MD
          data: { url: url_builder.new_project_url }
        )
      end

      def configure_consent_screen_instruction
        scopes = (@data['scopes'] || ['email', 'profile']).join(', ')

        Instruction.create!(
          service_configuration: @config,
          step_number: 2,
          title: "Configure OAuth Consent Screen",
          instruction_type: 'manual_action',
          instruction_text: <<~MD,
            ## Configure OAuth Consent Screen

            1. Go to **APIs & Services > OAuth consent screen**
            2. Select **External** user type → Click "Create"
            3. Fill in the following:

            **App Information:**
            - App name: `#{@data['app_name']}`
            - User support email: `#{@data['support_email']}`
            - App logo: #{@data['logo_url'] || '(Optional - upload later)'}

            **App Domain:**
            - Application home page: `https://#{@setup.domain || 'yourapp.com'}`
            - Privacy policy: `#{@data['privacy_policy_url']}`
            #{@data['terms_of_service_url'].present? ? "- Terms of service: `#{@data['terms_of_service_url']}`" : ''}

            **Developer Contact:**
            - Email: `#{@data['developer_contact']}`

            4. Click "Save and Continue"

            **Scopes:**
            5. Click "Add or Remove Scopes"
            6. Add these scopes: **#{scopes}**
            7. Click "Update" → "Save and Continue"

            **Test Users:** (Optional for development)
            8. Add your email as a test user
            9. Click "Save and Continue"
          MD
          data: {}
        )
      end

      def create_credentials_instruction
        redirect_uris = @data['redirect_uris']&.split("\n")&.map(&:strip)&.reject(&:blank?) || []

        credentials_snippet = <<~YAML
          google:
            client_id: YOUR_CLIENT_ID_HERE
            client_secret: YOUR_CLIENT_SECRET_HERE
        YAML

        Instruction.create!(
          service_configuration: @config,
          step_number: 3,
          title: "Create OAuth Credentials",
          instruction_type: 'copy_snippet',
          instruction_text: <<~MD,
            ## Create OAuth 2.0 Credentials

            1. Go to **APIs & Services > Credentials**
            2. Click "Create Credentials" → "OAuth client ID"
            3. Application type: **Web application**
            4. Name: `#{@data['app_name']} Web Client`

            **Authorized JavaScript origins:**
            - `https://#{@setup.domain || 'yourapp.com'}`
            - `http://localhost:3000` (for development)

            **Authorized redirect URIs:**
            #{redirect_uris.map { |uri| "- `#{uri}`" }.join("\n")}

            5. Click "Create"
            6. **Copy the Client ID and Client Secret** (you'll need these next)

            ---

            ## Add to Rails Credentials

            Run this command:
            ```bash
            EDITOR="code --wait" rails credentials:edit
            ```

            Add this configuration:
            ```yaml
            #{credentials_snippet}
            ```

            Replace `YOUR_CLIENT_ID_HERE` and `YOUR_CLIENT_SECRET_HERE` with the values from Google Console.
          MD
          data: { snippet: credentials_snippet, filename: 'config/credentials.yml.enc' }
        )
      end

      def add_to_devise_instruction
        devise_snippet = <<~RUBY
          # config/initializers/devise.rb
          config.omniauth :google_oauth2,
                          Rails.application.credentials.dig(:google, :client_id),
                          Rails.application.credentials.dig(:google, :client_secret),
                          scope: "#{(@data['scopes'] || ['email', 'profile']).join(',')}",
                          prompt: "select_account"
        RUBY

        Instruction.create!(
          service_configuration: @config,
          step_number: 4,
          title: "Configure Devise for Google OAuth",
          instruction_type: 'copy_snippet',
          instruction_text: <<~MD,
            ## Add Google OAuth to Devise

            Edit `config/initializers/devise.rb` and add this configuration:

            ```ruby
            #{devise_snippet}
            ```

            **Add to Gemfile** (if not already present):
            ```ruby
            gem 'omniauth-google-oauth2'
            gem 'omniauth-rails_csrf_protection'
            ```

            Then run:
            ```bash
            bundle install
            rails server
            ```

            **Test the OAuth flow:**
            Visit: `http://localhost:3000/users/auth/google_oauth2`
          MD
          data: { snippet: devise_snippet, filename: 'config/initializers/devise.rb' }
        )
      end

      def domain_verification_instruction
        Instruction.create!(
          service_configuration: @config,
          step_number: 5,
          title: "Domain Verification (Optional)",
          instruction_type: 'manual_action',
          instruction_text: <<~MD,
            ## Verify Your Domain (For Production)

            To remove the "unverified app" warning, verify your domain:

            1. Go to [Google Search Console](https://search.google.com/search-console/welcome)
            2. Add property: `#{@setup.domain || 'yourapp.com'}`
            3. Choose verification method (DNS TXT record recommended)
            4. Add the TXT record to your DNS
            5. Click "Verify"

            **Then in Google Cloud Console:**
            1. Go to OAuth consent screen
            2. Click "Submit for Verification"
            3. Provide screenshots and explanations of how your app uses Google data
            4. Wait for Google's approval (can take 2-4 weeks)

            **Note:** Your app works without verification, but users will see an "unverified app" warning.
          MD
          data: {}
        )
      end
    end
  end
end

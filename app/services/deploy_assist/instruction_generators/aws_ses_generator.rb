module DeployAssist
  module InstructionGenerators
    class AwsSesGenerator
      def initialize(service_configuration)
        @config = service_configuration
        @setup = service_configuration.deployment_setup
        @data = service_configuration.collected_data
        @results = service_configuration.automation_results
      end

      def generate
        if @data['verification_type'] == 'email'
          generate_email_verification_instructions
        else
          generate_domain_verification_instructions
        end
      end

      private

      def generate_domain_verification_instructions
        [
          create_verification_instruction,
          create_dns_records_instruction,
          create_actionmailer_config_instruction,
          create_production_access_instruction
        ]
      end

      def generate_email_verification_instructions
        [
          create_email_verification_instruction,
          create_actionmailer_config_instruction,
          create_production_access_instruction
        ]
      end

      def create_verification_instruction
        Instruction.create!(
          service_configuration: @config,
          step_number: 1,
          title: "Verify Domain Identity",
          instruction_type: 'manual_action',
          instruction_text: <<~MD,
            ## Domain Verification Started

            We've initiated domain verification for: **#{@data['domain']}**

            Verification token has been generated. You'll add DNS records in the next step.

            **Note:** It can take up to 72 hours for DNS changes to propagate, but usually completes within 15 minutes.
          MD
          data: {}
        )
      end

      def create_dns_records_instruction
        dns_records = @results.dig('ses_verification', 'dns_records') || generate_sample_dns_records

        table_rows = dns_records.map do |record|
          "| #{record[:type]} | `#{record[:name]}` | `#{record[:value]}` | #{record[:description]} |"
        end.join("\n")

        Instruction.create!(
          service_configuration: @config,
          step_number: 2,
          title: "Add DNS Records",
          instruction_type: 'copy_snippet',
          instruction_text: <<~MD,
            ## Add These DNS Records to #{@data['domain']}

            Go to your DNS provider (Cloudflare, Route53, etc.) and add these records:

            | Type | Name | Value | Purpose |
            |------|------|-------|---------|
            #{table_rows}

            **How to add DNS records:**
            1. Log into your DNS provider
            2. Go to DNS management for #{@data['domain']}
            3. Add each record from the table above
            4. Save changes

            **Verification:**
            After adding records, check verification status in AWS SES Console:
            [https://console.aws.amazon.com/ses/home?region=#{@data['region']}#verified-senders-domain:](https://console.aws.amazon.com/ses/home?region=#{@data['region']}#verified-senders-domain:)
          MD
          data: { dns_records: dns_records }
        )
      end

      def create_email_verification_instruction
        Instruction.create!(
          service_configuration: @config,
          step_number: 1,
          title: "Verify Email Address",
          instruction_type: 'manual_action',
          instruction_text: <<~MD,
            ## Email Address Verification

            1. Check the inbox for: **#{@data['email_address']}**
            2. Click the verification link in the email from AWS
            3. You'll see a confirmation page

            **Didn't receive the email?**
            - Check spam folder
            - Wait a few minutes and try again
            - Resend verification email from SES Console

            **Verify in SES Console:**
            [https://console.aws.amazon.com/ses/home?region=#{@data['region']}#verified-senders-email:](https://console.aws.amazon.com/ses/home?region=#{@data['region']}#verified-senders-email:)
          MD
          data: {}
        )
      end

      def create_actionmailer_config_instruction
        mailer_config = <<~RUBY
          # config/environments/production.rb
          config.action_mailer.delivery_method = :smtp
          config.action_mailer.smtp_settings = {
            address: 'email-smtp.#{@data['region']}.amazonaws.com',
            port: 587,
            user_name: ENV['SMTP_USERNAME'],
            password: ENV['SMTP_PASSWORD'],
            authentication: :plain,
            enable_starttls_auto: true
          }

          config.action_mailer.default_options = {
            from: '#{@data['from_name']} <#{@data['from_email']}>'
          }
        RUBY

        credentials_snippet = <<~YAML
          # Add to config/credentials.yml.enc
          aws:
            ses:
              smtp_username: YOUR_SMTP_USERNAME
              smtp_password: YOUR_SMTP_PASSWORD
        YAML

        Instruction.create!(
          service_configuration: @config,
          step_number: (@data['verification_type'] == 'email' ? 2 : 3),
          title: "Configure ActionMailer",
          instruction_type: 'copy_snippet',
          instruction_text: <<~MD,
            ## Configure Rails ActionMailer for SES

            ### 1. Get SMTP Credentials

            1. Go to [SES SMTP Settings](https://console.aws.amazon.com/ses/home?region=#{@data['region']}#smtp-settings:)
            2. Click "Create My SMTP Credentials"
            3. Download or copy the username and password

            ### 2. Add to Rails Credentials

            ```bash
            EDITOR="code --wait" rails credentials:edit
            ```

            Add this:
            ```yaml
            #{credentials_snippet}
            ```

            ### 3. Configure Production Environment

            Add to `config/environments/production.rb`:

            ```ruby
            #{mailer_config}
            ```

            ### 4. Update Environment Variables

            Add to `.kamal/secrets`:
            ```
            SMTP_USERNAME=<%= Rails.application.credentials.dig(:aws, :ses, :smtp_username) %>
            SMTP_PASSWORD=<%= Rails.application.credentials.dig(:aws, :ses, :smtp_password) %>
            ```
          MD
          data: { snippet: mailer_config, filename: 'config/environments/production.rb' }
        )
      end

      def create_production_access_instruction
        Instruction.create!(
          service_configuration: @config,
          step_number: (@data['verification_type'] == 'email' ? 3 : 4),
          title: "Request Production Access",
          instruction_type: 'manual_action',
          instruction_text: <<~MD,
            ## Move Out of SES Sandbox

            **New SES accounts are in "sandbox mode" with limitations:**
            - Can only send to verified email addresses
            - Limited to 200 emails per 24 hours
            - Max 1 email per second

            ### Request Production Access

            1. Go to [SES Account Dashboard](https://console.aws.amazon.com/ses/home?region=#{@data['region']}#account-details:)
            2. Click "Request production access"
            3. Fill out the form:
               - **Mail Type**: Transactional
               - **Website URL**: https://#{@setup.domain}
               - **Use Case**: Describe your application (e.g., "User notifications, password resets, welcome emails")
               - **Expected Volume**: Estimate daily emails
               - **Bounce/Complaint Handling**: "Yes, we handle bounces and complaints"
            4. Submit request

            **Approval Time:** Usually 24 hours (can be up to 48 hours)

            **After Approval:**
            - Send up to 50,000 emails/day (can request increases)
            - Send to any email address
            - Higher sending rate

            **Test Email in Sandbox Mode:**
            ```bash
            rails console
            UserMailer.welcome_email(User.first).deliver_now
            ```
            (Will only work if recipient is verified)
          MD
          data: {}
        )
      end

      def generate_sample_dns_records
        [
          {
            type: 'TXT',
            name: "_amazonses.#{@data['domain']}",
            value: 'VERIFICATION_TOKEN_HERE',
            description: 'SES Domain Verification'
          },
          {
            type: 'CNAME',
            name: "token1._domainkey.#{@data['domain']}",
            value: 'token1.dkim.amazonses.com',
            description: 'DKIM Signature'
          }
        ]
      end
    end
  end
end

require 'aws-sdk-ses'

module DeployAssist
  module Automation
    module Aws
      class SesService
        attr_reader :client

        def initialize(access_key_id, secret_access_key, region)
          @client = ::Aws::SES::Client.new(
            access_key_id: access_key_id,
            secret_access_key: secret_access_key,
            region: region
          )
          @region = region
        end

        def verify_domain(domain)
          # Initiate domain verification
          verify_response = @client.verify_domain_identity(domain: domain)

          # Get DKIM tokens
          dkim_response = @client.verify_domain_dkim(domain: domain)

          dns_records = generate_dns_records(domain, verify_response.verification_token, dkim_response.dkim_tokens)

          {
            success: true,
            verification_token: verify_response.verification_token,
            dkim_tokens: dkim_response.dkim_tokens,
            dns_records: dns_records
          }
        rescue ::Aws::SES::Errors::ServiceError => e
          {
            success: false,
            error: e.message,
            error_code: e.code
          }
        end

        def verify_email(email_address)
          @client.verify_email_identity(email_address: email_address)

          {
            success: true,
            email_address: email_address,
            message: "Verification email sent to #{email_address}"
          }
        rescue ::Aws::SES::Errors::ServiceError => e
          {
            success: false,
            error: e.message
          }
        end

        private

        def generate_dns_records(domain, verification_token, dkim_tokens)
          records = []

          # Verification TXT record
          records << {
            type: 'TXT',
            name: "_amazonses.#{domain}",
            value: verification_token,
            description: 'SES Domain Verification'
          }

          # DKIM CNAME records
          dkim_tokens.each do |token|
            records << {
              type: 'CNAME',
              name: "#{token}._domainkey.#{domain}",
              value: "#{token}.dkim.amazonses.com",
              description: 'DKIM Signature'
            }
          end

          # SPF TXT record (recommended)
          records << {
            type: 'TXT',
            name: domain,
            value: 'v=spf1 include:amazonses.com ~all',
            description: 'SPF Record (recommended)'
          }

          # DMARC TXT record (recommended)
          records << {
            type: 'TXT',
            name: "_dmarc.#{domain}",
            value: 'v=DMARC1; p=none; rua=mailto:postmaster@' + domain,
            description: 'DMARC Policy (recommended)'
          }

          records
        end
      end
    end
  end
end

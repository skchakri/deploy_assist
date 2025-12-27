module DeployAssist
  module InstructionGenerators
    class StripeGenerator
      def initialize(service_configuration)
        @config = service_configuration
        @setup = service_configuration.deployment_setup
        @data = service_configuration.collected_data
        @results = service_configuration.automation_results
      end

      def generate
        [
          create_account_instruction,
          get_api_keys_instruction,
          create_products_instruction,
          setup_webhooks_instruction,
          integrate_rails_instruction,
          testing_and_go_live_instruction
        ]
      end

      private

      def create_account_instruction
        Instruction.create!(
          service_configuration: @config,
          step_number: 1,
          title: "Create Stripe Account",
          instruction_type: 'external_link',
          instruction_text: <<~MD,
            ## Create Your Stripe Account

            1. Go to [Stripe Sign Up](https://dashboard.stripe.com/register)
            2. Enter your email and create a password
            3. Click "Create account"

            **Business Information to Provide:**
            - Legal business name: **#{@data['legal_business_name']}**
            - Country: **#{@data['country']}**
            - Business type: **#{@data['business_type']&.titleize}**
            - Business website: **#{@data['business_url']}**
            - Support email: **#{@data['support_email']}**
            #{@data['support_phone'].present? ? "- Support phone: **#{@data['support_phone']}**" : ''}

            **Verification Requirements:**
            - Stripe will ask for business verification documents
            - This can include: Tax ID, business license, bank statements
            - Verification usually takes 1-2 business days

            **Start in Test Mode:**
            - You can develop and test immediately in test mode
            - No verification needed for test mode
          MD
          data: { url: 'https://dashboard.stripe.com/register' }
        )
      end

      def get_api_keys_instruction
        credentials_snippet = <<~YAML
          # Add to config/credentials.yml.enc
          stripe:
            publishable_key: pk_test_YOUR_KEY_HERE
            secret_key: sk_test_YOUR_KEY_HERE
            webhook_secret: whsec_YOUR_WEBHOOK_SECRET
        YAML

        Instruction.create!(
          service_configuration: @config,
          step_number: 2,
          title: "Get API Keys",
          instruction_type: 'copy_snippet',
          instruction_text: <<~MD,
            ## Get Your Stripe API Keys

            ### 1. Find Your Keys

            1. Log into [Stripe Dashboard](https://dashboard.stripe.com)
            2. Click "Developers" in the sidebar
            3. Click "API keys"
            4. You'll see two keys:
               - **Publishable key** (starts with `pk_test_`)
               - **Secret key** (starts with `sk_test_`) - Click "Reveal test key"

            **⚠️ Important:** Start with TEST keys. Switch to LIVE keys only after thorough testing.

            ### 2. Add to Rails Credentials

            ```bash
            EDITOR="code --wait" rails credentials:edit
            ```

            Add this configuration:
            ```yaml
            #{credentials_snippet}
            ```

            **Save and close the file.**

            ### 3. Verify Credentials

            ```bash
            rails console
            Rails.application.credentials.dig(:stripe, :secret_key)
            # Should output: "sk_test_..."
            ```
          MD
          data: { snippet: credentials_snippet, filename: 'config/credentials.yml.enc' }
        )
      end

      def create_products_instruction
        product_list = (@data['product_names'] || '').split("\n").reject(&:blank?).map(&:strip)

        Instruction.create!(
          service_configuration: @config,
          step_number: 3,
          title: "Create Products & Prices",
          instruction_type: 'manual_action',
          instruction_text: <<~MD,
            ## Create Your Products in Stripe

            ### Products to Create:

            #{product_list.map.with_index(1) { |product, i| "#{i}. **#{product}**" }.join("\n")}

            ### Steps for Each Product:

            1. Go to [Stripe Products](https://dashboard.stripe.com/test/products)
            2. Click "+ Add product"
            3. Fill in product details:
               - **Name**: #{product_list.first || 'Your product name'}
               - **Description**: Describe what customers get
               - **Image**: Upload product image (optional)

            4. **Set Pricing:**
               - Currency: **#{@data['currency']&.upcase}**
               #{@data['price_type'] == 'recurring' ? '- Billing period: Monthly / Yearly / Custom' : '- Pricing: One-time payment'}
               #{@data['enable_subscriptions'] != false ? '- Trial period: Optional (e.g., 14 days free)' : ''}

            5. Click "Add product"

            ### Pricing Examples:

            #{pricing_examples}

            **Repeat for all products.**

            ### Get Product & Price IDs:

            After creating products, note down the IDs:
            - Product ID: `prod_xxxxx`
            - Price ID: `price_xxxxx`

            You'll need these for checkout sessions.
          MD
          data: {}
        )
      end

      def setup_webhooks_instruction
        webhook_url = @data['webhook_url']
        events = @data['events'] || []

        webhook_handler_code = <<~RUBY
          # app/controllers/webhooks/stripe_controller.rb
          module Webhooks
            class StripeController < ApplicationController
              skip_before_action :verify_authenticity_token

              def create
                payload = request.body.read
                sig_header = request.env['HTTP_STRIPE_SIGNATURE']
                endpoint_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

                begin
                  event = Stripe::Webhook.construct_event(
                    payload, sig_header, endpoint_secret
                  )
                rescue JSON::ParserError => e
                  render json: { error: 'Invalid payload' }, status: 400
                  return
                rescue Stripe::SignatureVerificationError => e
                  render json: { error: 'Invalid signature' }, status: 400
                  return
                end

                # Handle the event
                case event.type
                when 'payment_intent.succeeded'
                  handle_payment_success(event.data.object)
                when 'customer.subscription.created'
                  handle_subscription_created(event.data.object)
                when 'customer.subscription.deleted'
                  handle_subscription_cancelled(event.data.object)
                when 'invoice.payment_failed'
                  handle_payment_failed(event.data.object)
                end

                render json: { received: true }, status: 200
              end

              private

              def handle_payment_success(payment_intent)
                # Update your database
                # Send confirmation email
                Rails.logger.info "Payment succeeded: \#{payment_intent.id}"
              end

              def handle_subscription_created(subscription)
                # Activate user's subscription
                Rails.logger.info "Subscription created: \#{subscription.id}"
              end

              def handle_subscription_cancelled(subscription)
                # Deactivate user's subscription
                Rails.logger.info "Subscription cancelled: \#{subscription.id}"
              end

              def handle_payment_failed(invoice)
                # Notify user of failed payment
                Rails.logger.info "Payment failed: \#{invoice.id}"
              end
            end
          end
        RUBY

        Instruction.create!(
          service_configuration: @config,
          step_number: 4,
          title: "Setup Webhooks",
          instruction_type: 'copy_snippet',
          instruction_text: <<~MD,
            ## Configure Stripe Webhooks

            ### 1. Create Webhook Endpoint in Stripe

            1. Go to [Stripe Webhooks](https://dashboard.stripe.com/test/webhooks)
            2. Click "+ Add endpoint"
            3. Endpoint URL: `#{webhook_url}`
            4. Click "Select events"
            5. Choose these events:
            #{events.map { |e| "   - ✅ `#{e}`" }.join("\n")}
            6. Click "Add endpoint"

            ### 2. Get Webhook Signing Secret

            1. Click on your newly created webhook
            2. In the "Signing secret" section, click "Reveal"
            3. Copy the secret (starts with `whsec_`)
            4. Add to Rails credentials:

            ```bash
            EDITOR="code --wait" rails credentials:edit
            ```

            Add:
            ```yaml
            stripe:
              webhook_secret: whsec_YOUR_SECRET_HERE
            ```

            ### 3. Create Webhook Handler

            Create this file:
            ```ruby
            #{webhook_handler_code}
            ```

            ### 4. Add Route

            In `config/routes.rb`:
            ```ruby
            namespace :webhooks do
              resource :stripe, only: [:create]
            end
            ```

            ### 5. Test Webhook Locally

            Install Stripe CLI:
            ```bash
            brew install stripe/stripe-cli/stripe
            stripe login
            stripe listen --forward-to localhost:3000/webhooks/stripe
            ```

            Trigger test events:
            ```bash
            stripe trigger payment_intent.succeeded
            ```
          MD
          data: { snippet: webhook_handler_code, filename: 'app/controllers/webhooks/stripe_controller.rb' }
        )
      end

      def integrate_rails_instruction
        stripe_initializer = <<~RUBY
          # config/initializers/stripe.rb
          Rails.configuration.to_prepare do
            Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key)
          end
        RUBY

        checkout_example = <<~RUBY
          # Example: Create a checkout session
          def create_checkout_session
            session = Stripe::Checkout::Session.create(
              payment_method_types: ['card'],
              line_items: [{
                price: 'price_xxxxx', # Your price ID
                quantity: 1,
              }],
              mode: 'subscription', # or 'payment' for one-time
              success_url: "\#{root_url}success?session_id={CHECKOUT_SESSION_ID}",
              cancel_url: "\#{root_url}cancel",
            )

            redirect_to session.url, allow_other_host: true
          end
        RUBY

        Instruction.create!(
          service_configuration: @config,
          step_number: 5,
          title: "Integrate Stripe in Rails",
          instruction_type: 'copy_snippet',
          instruction_text: <<~MD,
            ## Add Stripe to Your Rails App

            ### 1. Add Gem

            Add to `Gemfile`:
            ```ruby
            gem 'stripe', '~> 12.0'
            ```

            Run:
            ```bash
            bundle install
            ```

            ### 2. Create Stripe Initializer

            ```ruby
            #{stripe_initializer}
            ```

            ### 3. Example: Checkout Session

            ```ruby
            #{checkout_example}
            ```

            ### 4. Frontend Integration

            Add Stripe.js to your layout:
            ```html
            <script src="https://js.stripe.com/v3/"></script>
            ```

            **Publishable Key (use in frontend):**
            ```javascript
            const stripe = Stripe('<%= Rails.application.credentials.dig(:stripe, :publishable_key) %>');
            ```

            ### Resources:

            - [Stripe Rails Guide](https://stripe.com/docs/payments/checkout)
            - [Stripe Checkout](https://stripe.com/docs/payments/checkout/how-checkout-works)
            - [Subscription Billing](https://stripe.com/docs/billing/subscriptions/overview)
          MD
          data: { snippet: stripe_initializer, filename: 'config/initializers/stripe.rb' }
        )
      end

      def testing_and_go_live_instruction
        Instruction.create!(
          service_configuration: @config,
          step_number: 6,
          title: "Testing & Go Live",
          instruction_type: 'manual_action',
          instruction_text: <<~MD,
            ## Test & Go Live with Stripe

            ### Test Mode Checklist:

            ✅ **Test Cards** (use these in test mode):
            - Success: `4242 4242 4242 4242`
            - Decline: `4000 0000 0000 0002`
            - 3D Secure: `4000 0025 0000 3155`
            - Any future expiry date, any CVC

            ✅ **Test Scenarios:**
            - [ ] Successful one-time payment
            - [ ] Successful subscription signup
            - [ ] Failed payment handling
            - [ ] Subscription cancellation
            - [ ] Webhook delivery and processing
            - [ ] Refund processing

            ### Before Going Live:

            1. **Complete Stripe Account Verification**
               - Submit business documents
               - Verify bank account for payouts
               - Wait for approval (1-2 business days)

            2. **Switch to Live Mode**
               - Go to [API Keys](https://dashboard.stripe.com/apikeys)
               - Get LIVE keys (start with `pk_live_` and `sk_live_`)
               - Update Rails credentials with live keys
               - Update webhook endpoint URL (remove /test/ from path)

            3. **Production Checklist**
               - [ ] Test all payment flows in live mode with real card
               - [ ] Verify webhooks are working in production
               - [ ] Set up proper error monitoring (Sentry, Honeybadger)
               - [ ] Configure email notifications for failed payments
               - [ ] Review Stripe fees for your country (usually 2.9% + 30¢)

            ### Monitoring:

            **Stripe Dashboard:**
            - [Payments](https://dashboard.stripe.com/payments)
            - [Subscriptions](https://dashboard.stripe.com/subscriptions)
            - [Customers](https://dashboard.stripe.com/customers)
            - [Logs](https://dashboard.stripe.com/logs)

            **Rails Monitoring:**
            ```ruby
            # Log all Stripe events
            Stripe.log_level = Stripe::LEVEL_INFO
            ```

            ### Common Issues:

            - **Webhooks not received**: Check endpoint URL is publicly accessible
            - **Payment declined**: Verify test card numbers or check actual card
            - **Subscription not created**: Ensure customer has payment method attached
            - **Invalid API key**: Double-check credentials and test/live mode

            🎉 **You're ready to accept payments!**
          MD
          data: {}
        )
      end

      def pricing_examples
        case @data['price_type']
        when 'recurring'
          <<~MD
            - **Monthly Plan**: $9.99/month
            - **Annual Plan**: $99/year (save 17%)
            - **Usage-based**: $0.10 per unit
          MD
        when 'one_time'
          <<~MD
            - **Basic**: $29 one-time
            - **Premium**: $99 one-time
            - **Enterprise**: $499 one-time
          MD
        else
          <<~MD
            - **One-time**: $29 (single purchase)
            - **Monthly**: $9.99/month (recurring)
            - **Lifetime**: $199 (one-time, unlimited access)
          MD
        end
      end
    end
  end
end

require 'stripe'

module DeployAssist
  module Automation
    class StripeService
      attr_reader :api_key

      def initialize(api_key)
        @api_key = api_key
        Stripe.api_key = api_key
      end

      def create_products_and_prices(product_names, currency, price_type)
        products = []
        product_names.split("\n").reject(&:blank?).each do |name|
          begin
            product = Stripe::Product.create(
              name: name.strip,
              description: "#{name.strip} - Auto-created by DeployAssist"
            )

            # Create a sample price (user will configure actual prices later)
            price = create_sample_price(product.id, currency, price_type)

            products << {
              id: product.id,
              name: product.name,
              price_id: price&.id,
              success: true
            }
          rescue Stripe::StripeError => e
            products << {
              name: name.strip,
              success: false,
              error: e.message
            }
          end
        end

        {
          success: products.any? { |p| p[:success] },
          products: products
        }
      rescue Stripe::StripeError => e
        {
          success: false,
          error: e.message,
          error_code: e.code
        }
      end

      def setup_webhook_endpoint(webhook_url, events)
        webhook = Stripe::WebhookEndpoint.create(
          url: webhook_url,
          enabled_events: events || default_webhook_events,
          description: 'Created by DeployAssist'
        )

        {
          success: true,
          webhook_id: webhook.id,
          webhook_secret: webhook.secret,
          url: webhook.url,
          enabled_events: webhook.enabled_events
        }
      rescue Stripe::StripeError => e
        {
          success: false,
          error: e.message,
          error_code: e.code
        }
      end

      def verify_api_key
        # Test the API key by fetching account info
        account = Stripe::Account.retrieve
        {
          success: true,
          account_id: account.id,
          country: account.country,
          email: account.email,
          business_name: account.business_profile&.name
        }
      rescue Stripe::StripeError => e
        {
          success: false,
          error: e.message
        }
      end

      private

      def create_sample_price(product_id, currency, price_type)
        # Create a placeholder price
        # User will create actual prices in Stripe Dashboard
        return nil if price_type == 'one_time'

        Stripe::Price.create(
          product: product_id,
          unit_amount: 999, # $9.99 placeholder
          currency: currency,
          recurring: { interval: 'month' }
        )
      rescue Stripe::StripeError
        # If price creation fails, that's okay - products are still created
        nil
      end

      def default_webhook_events
        [
          'payment_intent.succeeded',
          'payment_intent.payment_failed',
          'customer.subscription.created',
          'customer.subscription.updated',
          'customer.subscription.deleted',
          'invoice.payment_succeeded',
          'invoice.payment_failed',
          'checkout.session.completed'
        ]
      end
    end
  end
end

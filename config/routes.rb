DeployAssist::Engine.routes.draw do
  root to: 'dashboard#index'

  resources :setups, only: [:index, :show, :create, :new] do
    member do
      get :configure_service
      post :add_service
    end
  end

  namespace :wizards do
    get 'aws_deployment/step/:step_number', to: 'aws_deployment#show', as: :aws_deployment_step
    patch 'aws_deployment/step/:step_number', to: 'aws_deployment#update'

    get 'google_oauth/step/:step_number', to: 'google_oauth#show', as: :google_oauth_step
    patch 'google_oauth/step/:step_number', to: 'google_oauth#update'

    get 'aws_ses/step/:step_number', to: 'aws_ses#show', as: :aws_ses_step
    patch 'aws_ses/step/:step_number', to: 'aws_ses#update'

    get 'stripe/step/:step_number', to: 'stripe#show', as: :stripe_step
    patch 'stripe/step/:step_number', to: 'stripe#update'

    get 'chrome_extension/step/:step_number', to: 'chrome_extension#show', as: :chrome_extension_step
    patch 'chrome_extension/step/:step_number', to: 'chrome_extension#update'
  end

  resources :instructions, only: [:index, :show] do
    member do
      post :mark_complete
    end
  end
end

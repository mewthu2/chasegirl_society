Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]
  resource :account, only: %i[edit update]

  root "dashboard#show"

  # Área da influenciadora
  get "minha-area", to: "portal#show", as: :portal

  resources :influencers do
    member do
      post :access, to: "influencers#save_access"
      delete :access, to: "influencers#revoke_access"
      post :send_access
      get :coupon
    end
  end

  resources :proofs, path: "comprovacoes" do
    member do
      post :approve
      post :reject
      post :reopen
    end
  end

  # Módulo financeiro
  scope "financeiro" do
    resources :statements, path: "a-pagar", only: %i[index show] do
      member do
        post :pay
        post :unpay
        post :coupon
      end
    end
  end

  resources :users, path: "usuarios", except: :show

  mount ActiveStorageDB::Engine => "/active_storage_db"
  get "up" => "rails/health#show", as: :rails_health_check
end

Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]
  get "primeiro-acesso", to: "first_access#new", as: :first_access
  post "primeiro-acesso", to: "first_access#lookup"
  post "primeiro-acesso/cadastro", to: "first_access#create", as: :first_access_register
  get "primeiro-acesso/confirmar/:token", to: "first_access#confirm", as: :first_access_confirm
  get "convite/:token", to: "invitations#show", as: :invitation
  patch "convite/:token", to: "invitations#update"
  resource :account, only: %i[edit update]

  root "dashboard#show"

  # Área da influenciadora
  get "minha-area", to: "portal#show", as: :portal

  resources :influencers do
    member do
      post :access, to: "influencers#save_access"
      delete :access, to: "influencers#revoke_access"
      post :resend_invitation
      get :coupon
      post :reactivate
    end
  end

  resources :proofs, path: "comprovacoes" do
    member do
      post :approve
      post :reject
      post :reopen
    end
  end

  # Conferência mensal (o mês aprova sozinho ao cumprir as metas)
  resources :reviews, path: "conferencia", only: %i[index show] do
    member do
      post :reopen
      post :coupon
    end
  end

  # Módulo financeiro
  scope "financeiro" do
    resources :statements, path: "a-pagar", only: %i[index] do
      member do
        post :pay
        post :unpay
      end
    end
    get "pagos", to: "statements#paid", as: :paid_statements
  end

  resources :users, path: "usuarios", except: :show do
    post :invite, on: :member
  end

  mount ActiveStorageDB::Engine => "/active_storage_db"
  get "up" => "rails/health#show", as: :rails_health_check
end

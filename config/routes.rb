HarvesterManager::Application.routes.draw do

  resources :parsers do
    resources :parser_versions, path: "versions", only: [:show, :update] do
      get :current, on: :collection
    end
  end

  resources :snippets, except: [:show] do
    get "search", on: :collection
  end

  scope ":environment", as: "environment" do
    resources :abstract_jobs, only: [:index], path: "jobs"
    resources :harvest_jobs, only: [:create, :update, :show]
    resources :enrichment_jobs, only: [:create, :update, :show]
    resources :harvest_schedules
  end

  match "/parsers/:parser_id/preview" => "records#index", as: :preview

  devise_for :users

  root :to => "parsers#index"
end
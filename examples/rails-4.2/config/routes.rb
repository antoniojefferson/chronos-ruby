ChronosLegacyExample::Application.routes.draw do
  get "/ok", :to => "diagnostics#ok"
  get "/fail", :to => "diagnostics#fail"
end

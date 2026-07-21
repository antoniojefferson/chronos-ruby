require "chronos/capistrano"

# Add these values to config/deploy.rb or a stage file.
set :chronos_version, ENV["APP_VERSION"]
set :chronos_actor, ENV["DEPLOY_USER"]
set :chronos_deploy_id, ENV["DEPLOY_ID"]
set :chronos_service, "billing"
set :chronos_region, ENV["DEPLOY_REGION"]

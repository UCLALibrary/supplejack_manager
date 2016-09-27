# The majority of The Supplejack Manager code is Crown copyright (C) 2014, New Zealand Government,
# and is licensed under the GNU General Public License, version 3. Some components are 
# third party components that are licensed under the MIT license or otherwise publicly available. 
# See https://github.com/DigitalNZ/supplejack_manager for details. 
# 
# Supplejack was created by DigitalNZ at the National Library of NZ and the Department of Internal Affairs. 
# http://digitalnz.org/supplejack

# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
HarvesterManager::Application.initialize!
active_resource_logger = Logger.new('log/active_resource.log', 'daily'); 
active_resource_logger.level = Rails.env.dev? ? Logger::DEBUG : Logger::INFO; 
ActiveResource::Base.logger = active_resource_logger
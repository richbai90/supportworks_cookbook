# Cookbook Name:: supportworks
# Recipe:: customize
#
# Copyright 2017, Bittercreek Technology, Inc
#
# All rights reserved - Do Not Redistribute

supportworks_customization node['supportworks']['customizations'] do
  cache_db_user 'root'
  cache_db_password node['supportworks']['root_password']
end
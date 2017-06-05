#
# Cookbook Name:: supportworks
# Recipe:: default
#
# Copyright 2017, Bittercreek Technology, Inc
#
# All rights reserved - Do Not Redistribute

supportworks_core_services 'cs' do
  action :install #default
  path 'C:\Hornbill'
  root_pw 'testing'
  version '6.0'
end

supportworks_migrate '192.168.1.136' do
  user 'migrate'
  password 'password'
  root_user 'root'
  root_pw 'testing'
  update_password true
  old_root_password ''
  # swdata_user nil
  # swdata_pw nil
  swdata_dsn 'Supportworks Data' #default
end

supportworks_server 'C:\Program Files (x86)\Hornbill\Supportworks Server' do
  action :install
  version '8.2'
  path :default # overwrites what's in the name. Tells the automator to use the default path
  license '------------------ BEGIN KEY -------------------
9ef28a30c8333dc15d4394d206d9d3dc7ed95ebfcbc010e8
0c40b51b741f2aee0a4f3dd3b64793f58e61cb880f1b9478
c9aa3b45dd8edf4a6d9c76a7df19693b45cf6e171e17fdaa
f08ae91b0f919896a1b452e244b0e093fb62c34ecddaccb7
f5ad195d344c376e8463fcbff1866bf383e978ed54d7bced
b4aa671b9c652c03613982629c56a427666078de56e42734
c05e2c8cf3ad5664b574648dbb1d5deb8065868e8d34e7a4
930365f6fbdcf6368e35e2d2608d3cd40612555b
------------------- END KEY --------------------'
  db_type :sw
  cache_db_user 'root'
  cache_db_password 'testing'
  sw_admin_pw 'password'
end

supportworks_server 'C:\Program Files (x86)\Hornbill\Supportworks Server' do
  action :configure
  version '8.2'
  license 'Bittercreek Technology, Inc'
end
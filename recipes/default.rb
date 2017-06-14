#
# Cookbook Name:: supportworks
# Recipe:: default
#
# Copyright 2017, Bittercreek Technology, Inc
#
# All rights reserved - Do Not Redistribute

supportworks_core_services 'cs' do
  action :install #default
  path 'D:\Program Files (x86)\Hornbill\Core Services'
  root_pw 'testing'
  version '6.0'
  media 'D:\swmedia'
end

supportworks_migrate '192.168.1.145' do
  from_user 'migrate'
  from_password 'password'
  to_user 'root'
  to_password 'testing'
  update_password true
  swdata_dsn 'Supportworks Data' #default
end

supportworks_server 'D:\Program Files (x86)\Hornbill\Supportworks Server' do
  action :install
  version '8.2'
  # path :default # overwrites what's in the name. Tells the automator to use the default path
  license '------------------ BEGIN KEY -------------------
5099d662ad650d6fa16d8090f7eb3801de3784f3db2c1a4f
d22ae9f3ef437a6caff2f21454e6004e4849bdd536aa6397
111aa54a0b46d0d9c6ef5c2e6761ad4f87f03e9a80eb1f73
ee22d0be1e22c8ff5e015b7e6b1ce7d56c4cb8708de3fb01
ee6024d39da9847fa880d67d41df3e8dbcc775fc23d48a2f
b92749f04dea67f38ae371bdd59e2b34805838372be49692
ef500411d065beaf96fb7cc87ecced50d39c9a7dcf109d9a
aaf24cccc048b8b3e1160b9155776cef12a8e148
------------------- END KEY --------------------'
  db_type :sw
  cache_db_user 'root'
  cache_db_password 'testing'
  sw_admin_pw 'password'
  media 'D:\swmedia'
end

supportworks_server 'D:\Program Files (x86)\Hornbill\Supportworks Server' do
  action :configure
  version '8.2'
  license 'Bittercreek Technology, Inc'
  media 'D:\swmedia'
  fqdn true
end

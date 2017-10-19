supportworks_migrate node['supportworks']['migrate_data_from'] do
  from_user node['supportworks']['migrate_using_user'] # this is the user we are using to migrate from the server at the address specified in the name
  from_password node['supportworks']['migrate_using_password'] # this is the password for the migrate user
  to_user 'root' # this is the user that will have root privileges and that sw will use when accessing the db on the new server
  to_password node['supportworks']['root_password'] # this is the password for the aforementioned user
  update_password true # this option says to update the password to the value in the to_password if it is not the same leave it be
  swdata_dsn 'Supportworks Data' #default
end

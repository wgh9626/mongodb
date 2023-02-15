#!/bin/bash
user_secret_template="config/samples/user/user-secret.yaml.template"
user_secret="config/samples/user/user-secret.yaml"
read -p 'Please input new database name: ' db_name
db_user=$db_name
cp ${user_secret_template} ${user_secret}
random_pass=$(tr -dc '_A-Za-z0-9' </dev/urandom | head -c 10)
sed -i "s/<db-user-secret>/${db_user}-password/" ${user_secret}
sed -i "s/<my-plain-text-password>/$random_pass/" ${user_secret}
echo "New Database $db_name password is $random_pass"

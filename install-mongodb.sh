#!/bin/bash

# Install MongoDB 4.4 on Ubuntu 18.04
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
sudo apt-get update
sudo apt-get install -y mongodb-org

sleep 5

# Update bindIp to 0.0.0.0 to allow external connections
sudo sed -i "s/^  bindIp:.*$/  bindIp: 0.0.0.0/" /etc/mongod.conf

# Enable and start MongoDB
sudo systemctl enable mongod
sudo systemctl restart mongod

# Wait for MongoDB to fully start
sleep 10

# Create admin user
mongo <<EOF
use admin
db.createUser({
  user: "admin",
  pwd: "mongo",
  roles: [ { role: "root", db: "admin" } ]
})
EOF


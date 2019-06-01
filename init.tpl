#!/bin/bash
set -x

exec > >(tee /var/log/berk-data.log) 2>&1

echo "Performing updates and installing prerequisites"
sudo apt-get -qq -y update

cd /home/berk
git clone https://github.com/berkkarabacak/microservicedemo.git
cd microservicedemo
sudo apt-get install leiningen -y
sudo apt-get install build-essential -y
make libs
make clean all
mkdir /opt/prod
sudo cp -r ./build/* /opt/prod/

# Set local/private IP address
local_ipv4="$(echo -e `hostname -I` | tr -d '[:space:]')"

echo "###############################"
echo "$${local_ipv4}"
echo "###############################"

###############################
# Create Assets Systemd Service
###############################
sudo mkdir -p /tmp/Assets/init/systemd/
sudo tee /tmp/Assets/init/systemd/Assets.service <<'EOF'
[Unit]
Description=Assets Agent
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
ExecStart=/usr/bin/python3 /home/berk/microservicedemo/front-end/public/serve.py
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

###############################
# Create Quote Systemd Service
###############################
sudo mkdir -p /tmp/Quote/init/systemd/
sudo tee /tmp/Quote/init/systemd/Quote.service <<'EOF'
[Unit]
Description=Quote Agent
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
ExecStart=/usr/bin/java -jar /opt/prod/quotes.jar
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF


###############################
# Create Newsfeed Systemd Service
###############################
sudo mkdir -p /tmp/Newsfeed/init/systemd/
sudo tee /tmp/Newsfeed/init/systemd/Newsfeed.service <<'EOF'
[Unit]
Description=Newsfeed Agent
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
ExecStart=/usr/bin/java -jar /opt/prod/newsfeed.jar
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF


###############################
# Create FrontEnd Systemd Service
###############################
sudo mkdir -p /tmp/FrontEnd/init/systemd/
sudo tee /tmp/FrontEnd/init/systemd/FrontEnd.service <<'EOF'
[Unit]
Description=FrontEnd Agent
Requires=network-online.target
After=network-online.target

[Service]
Environment="STATIC_URL=http://localhost:8000"
Environment="QUOTE_SERVICE_URL=http://10.0.2.20:8080"
Environment="NEWSFEED_SERVICE_URL=http://10.0.2.21:8080"
Environment="NEWSFEED_SERVICE_TOKEN=T1&eWbYXNWG1w1^YGKDPxAWJ@^et^&kX"
Restart=on-failure
ExecStart=/usr/bin/java -jar /opt/prod/front-end.jar
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

SYSTEMD_DIR="/lib/systemd/system"
echo "Installing systemd services"
sudo cp /tmp/Assets/init/systemd/Assets.service $${SYSTEMD_DIR}
sudo chmod 0664 $${SYSTEMD_DIR}/Assets.service

sudo cp /tmp/Quote/init/systemd/Quote.service $${SYSTEMD_DIR}
sudo chmod 0664 $${SYSTEMD_DIR}/Quote.service

sudo cp /tmp/Newsfeed/init/systemd/Newsfeed.service $${SYSTEMD_DIR}
sudo chmod 0664 $${SYSTEMD_DIR}/Newsfeed.servicet

sudo cp /tmp/FrontEnd/init/systemd/FrontEnd.service $${SYSTEMD_DIR}
sudo chmod 0664 $${SYSTEMD_DIR}/FrontEnd.service


if [ "$${local_ipv4}" = "10.0.2.20" ]
then
  echo "QUOTE is starting"
  sudo systemctl enable Quote
  sudo systemctl start Quote

elif [ "$${local_ipv4}" == "10.0.2.21" ]
then
  echo "Newsfeed is starting"
  sudo systemctl enable Newsfeed
  sudo systemctl start Newsfeed

elif [ "$${local_ipv4}" == "10.0.2.22" ]
then
  echo "FrontEND is starting"
  sudo systemctl enable Assets
  sudo systemctl start Assets
  sudo systemctl enable FrontEnd
  sudo systemctl start FrontEnd
fi

printenv

echo "Completed Configuration"


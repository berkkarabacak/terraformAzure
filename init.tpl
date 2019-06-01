#!/bin/bash
set -x

exec > >(tee /var/log/terraform-init-data.log) 2>&1

echo "Performing updates and installing prerequisites"
sudo apt-get -qq -y update

cd /home/${Username}
dir=microservicedemo
git clone https://github.com/berkkarabacak/microservicedemo.git "$${dir}"
cd $${dir}
sudo apt-get install leiningen -y
sudo apt-get install build-essential -y
make libs
make clean all
mkdir /opt/test
sudo cp -r ./build/* /opt/test/

# Set local/private IP address
local_ipv4="$(echo -e `hostname -I` | tr -d '[:space:]')"


###############################
# Create Assets Systemd Service
###############################
sudo mkdir -p /tmp/assets/init/systemd/
sudo tee /tmp/assets/init/systemd/assets.service <<EOF
[Unit]
Description=Assets Agent
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
ExecStart=/usr/bin/python3 /home/${Username}/$${dir}/front-end/public/serve.py
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

###############################
# Create Quote Systemd Service
###############################
sudo mkdir -p /tmp/quote_service/init/systemd/
sudo tee /tmp/quote_service/init/systemd/quote_service.service <<EOF
[Unit]
Description=Quote Agent
Requires=network-online.target
After=network-online.target

[Service]
Environment="APP_PORT=${QuoteServicePort}"
Restart=on-failure
ExecStart=/usr/bin/java -jar /opt/test/quotes.jar
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

###############################
# Create Newsfeed Systemd Service
###############################
sudo mkdir -p /tmp/Newsfeed/init/systemd/
sudo tee /tmp/Newsfeed/init/systemd/Newsfeed.service <<EOF
[Unit]
Description=Newsfeed Agent
Requires=network-online.target
After=network-online.target

[Service]
Environment="APP_PORT=${NewsfeedServicePort}"
Restart=on-failure
ExecStart=/usr/bin/java -jar /opt/test/newsfeed.jar
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF


###############################
# Create FrontEnd Systemd Service
###############################
sudo mkdir -p /tmp/FrontEnd/init/systemd/
sudo tee /tmp/FrontEnd/init/systemd/FrontEnd.service <<EOF
[Unit]
Description=FrontEnd Agent
Requires=network-online.target
After=network-online.target

[Service]
Environment="APP_PORT=${FrontEndServicePort}"
Environment="STATIC_URL=http://${FrontEndServicePublicIP}:8000/home/${Username}/$${dir}/front-end/public"
Environment="QUOTE_SERVICE_URL=http://${QuoteServicePrivateIP}:${QuoteServicePort}"
Environment="NEWSFEED_SERVICE_URL=http://${NewsfeedServicePrivateIP}:${NewsfeedServicePort}"
Environment="NEWSFEED_SERVICE_TOKEN=T1&eWbYXNWG1w1^YGKDPxAWJ@^et^&kX"
Restart=on-failure
ExecStart=/usr/bin/java -jar /opt/test/front-end.jar
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

SYSTEMD_DIR="/lib/systemd/system"
echo "Installing systemd services"
sudo cp /tmp/assets/init/systemd/assets.service $${SYSTEMD_DIR}
sudo chmod 0664 $${SYSTEMD_DIR}/assets.service

sudo cp /tmp/quote_service/init/systemd/quote_service.service $${SYSTEMD_DIR}
sudo chmod 0664 $${SYSTEMD_DIR}/quote_service.service

sudo cp /tmp/Newsfeed/init/systemd/Newsfeed.service $${SYSTEMD_DIR}
sudo chmod 0664 $${SYSTEMD_DIR}/Newsfeed.servicet

sudo cp /tmp/FrontEnd/init/systemd/FrontEnd.service $${SYSTEMD_DIR}
sudo chmod 0664 $${SYSTEMD_DIR}/FrontEnd.service


if [ "$${local_ipv4}" = "${QuoteServicePrivateIP}" ]
then
  echo "QUOTE is starting"
  sudo systemctl enable quote_service
  sudo systemctl start quote_service

elif [ "$${local_ipv4}" == "${NewsfeedServicePrivateIP}" ]
then
  echo "Newsfeed is starting"
  sudo systemctl enable Newsfeed
  sudo systemctl start Newsfeed

elif [ "$${local_ipv4}" == "${FrontEndServicePrivateIP}" ]
then
  echo "FrontEND is starting"
  sudo systemctl enable assets
  sudo systemctl start assets
  sudo systemctl enable FrontEnd
  sudo systemctl start FrontEnd
fi

echo "Completed Configuration"


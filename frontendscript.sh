export APP_PORT="80"
export STATIC_URL="$0"
export QUOTE_SERVICE_URL="$1"
export NEWSFEED_SERVICE_URL="$2"
export NEWSFEED_SERVICE_TOKEN='T1&eWbYXNWG1w1^YGKDPxAWJ@^et^&kX'
git clone https://github.com/berkkarabacak/microservicedemo.git
cd microservicedemo
sudo apt-get install leiningen -y
sudo apt-get install build-essential -y
make libs
make clean all
cd build
java -jar front-end.jar
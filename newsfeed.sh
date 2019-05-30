git clone https://github.com/berkkarabacak/microservicedemo.git
cd microservicedemo
sudo apt-get install leiningen -y
sudo apt-get install build-essential -y
make libs
make clean all
cd build
export APP_PORT="80"
java -jar newsfeed.jar


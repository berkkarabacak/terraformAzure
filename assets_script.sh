git clone https://github.com/berkkarabacak/microservicedemo.git
cd microservicedemo
sudo apt-get install leiningen -y
sudo apt-get install build-essential -y
make libs
make clean all
cd front-end/public
python3 serve.py
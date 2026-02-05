./01_build_base_img.sh local
./02_build_start_con.sh local




# First you have create network

docker network create asterisk-net

# Docker build command

docker build -t my-asterisk-app .

# Docker run command

docker run -d --name asterisk_server --network asterisk-net -p 5038:5038 -p 5060:5060/udp -p 10000-10010:10000-10010/udp my-asterisk-app asterisk -cvvvvvf    

# Docker container delete and image build container rerun command


docker rm -f asterisk_server && docker build -t my-asterisk-app . && docker run -d --name asterisk_server --network asterisk-net -p 5038:5038 -p 5060:5060/udp -p 8089:8089 -p 10000-10010:10000-10010/udp my-asterisk-app asterisk -cvvvvvf

docker rm -f asterisk_server && docker build --no-cache -t my-asterisk-app . && docker run -d --name asterisk_server --network asterisk-net -p 5038:5038  -p 5060:5060/udp  -p 8089:8089 -p 10000-10100:10000-10100/udp  my-asterisk-app  


## pjsip

asterisk -rvvv

pjsip reload

pjsip show transports

pjsip show endpoints

pjsip show contacts

pjsip set logger on

## To make call from terminal

channel originate PJSIP/1000 extension 1000@from-internal

## download sip.min.js file

wget https://cdn.jsdelivr.net/npm/sip.js@0.21.2/dist/sip.min.js


## key check

docker exec -it asterisk_server bash

ls -l /etc/asterisk/keys/


## Before register should visit the url

https://localhost:8088


# To add extension via terminal the below command will add 1002 extension

docker exec -it asterisk_server bash

echo -e "\n; --- User 1002 ---\n[1002](webrtc-template)\naors=1002\nauth=auth1002\n\n[1002](aor-template)\n\n[auth1002](auth-template)\nusername=1002\npassword=pass1002" | sudo tee -a /etc/asterisk/pjsip.endpoint_custom_post.conf

asterisk -rvvv

pjsip reload


docker exec -it asterisk_server asterisk -rvvvvv

pjsip reload



apt-get update && apt-get install -y unixodbc unixodbc-dev

apt-get update
apt-get install -y unixodbc unixodbc-dev libodbc1 odbcinst


###

apt-get update
apt-get install -y unixodbc unixodbc-dev odbc-mariadb

apt-get update
apt-get install -y mariadb-connector-odbc unixodbc

apt-get update
apt-get install -y unixodbc unixodbc-dev libodbc1 odbcinst


apt-get update && apt-get install -y unixodbc unixodbc-dev


apt-get update && apt-get install -y mariadb-client

apt-get update
apt-get install -y unixodbc unixodbc-dev odbc-mariadb




apt-get update && apt-get install -y nano

#### 



isql -v asterisk-connector asterisk_user asterisk_password

cat <<EOF > /etc/odbc.ini
[asterisk-connector]
Description = MariaDB Connector
Driver      = MariaDB
Server      = cts-mysql
User        = asterisk_user
Password    = asterisk_password
Database    = asterisk_db
Port        = 3306
EOF

cat /etc/odbc.ini

nano /etc/asterisk/odbc.ini
nano /etc/asterisk/cdr_adaptive_odbc.conf

cat /etc/asterisk/cdr_adaptive_odbc.conf


nano /etc/asterisk/extensions.conf
cat /etc/asterisk/extensions.conf


apt-get update
apt-get install -y unixodbc unixodbc-dev

apt-get install -y libmariadb3 libmariadb-dev

ls -l /usr/lib/asterisk/modules/func_odbc.so

ldd /usr/lib/asterisk/modules/func_odbc.so

core stop now

apt-get update && apt-get install -y dos2unix


  
    DB_ROOT_PASSWORD="supersecretrootpassword"
DB_NAME="asterisk_db"
DB_USER="asterisk_user"
DB_PASSWORD="asterisk_password"
DB_HOST="localhost"


cd /etc/asterisk

cat > cdr.conf <<EOF
[general]
enable=yes
unanswered=yes
default_handler=my_cdr_handle
EOF

module load cdr
module reload cdr
cdr show status

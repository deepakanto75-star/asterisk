## About 

- step 1   - Using dockerfile i am building image `debian:bullseye-slim AS pjproject-builder` to setup the asterisk server 

- step 2   - using dockerfile i am building image `mariadb:10.6` to setup the database for the asterisk server

- step 3   - using dockerfile i am building image `python:3.11-slim` to setup the frontend to make call and communicator



## Step 1 

docker exec -it cts-asterisk bash

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


- TO ckeck database connection 

- to see number of active connections `odbc show all`
- if not connected proceed below steps

- to reload the modules `module reload cdr_adaptive_odbc.so`
                        `module reload res_odbc.so`
                        `module reload func_odbc.so`


## Step 2 - verify the certificate

https://localhost:8088


## Step 3 - Register the agent

On this url `http://localhost:5000/` register agent using the agent credensials


# Manual run commands

 docker run -d \
        --name cts-asterisk \
        --network cts-network \
        -p 5038:5038 \
        -p 5060:5060/udp \
        -p 5061:5061/tcp \
        -p 8088:8088 \
        -p 8089:8089 \
        -p 10000-10020:10000-10020/udp \
        --restart always \
        -v /opt/asterisk_recordings:/var/spool/asterisk/monitor \
        cts-asterisk


docker run -d \
        --name cts-mysql \
        --network cts-network \
        -e MYSQL_ROOT_PASSWORD=supersecretrootpassword \
        -e MYSQL_DATABASE=asterisk_db \
        -e MYSQL_USER=asterisk_user \
        -e MYSQL_PASSWORD=asterisk_password \
        --restart always \
        cts-mysql

 docker run -d \
    --name cts-frontend \
    --network cts-network \
    -p 5000:5000 \
    -e DB_HOST=cts-mysql \
    -e DB_NAME=asterisk_db \
    -e DB_USER=asterisk_user \
    -e DB_PASSWORD=asterisk_password \
    --restart always \
    cts-frontend



## Others

asterisk -rvvv

pjsip reload

dialplan reload

pjsip show transports

pjsip show endpoints

pjsip show contacts

http show status

pjsip set logger on

### to verify database related things

- to see number of active connections `odbc show all`
- if not connected proceed below steps

- to reload the modules `module reload cdr_adaptive_odbc.so`
                        `module reload res_odbc.so`
                        `module reload func_odbc.so`
                        `cdr show status`

## key check

ls -l /etc/asterisk/keys/


 
## To genarete certificate

cd /etc/asterisk/keys

# Remove old keys if needed
rm -f asterisk.pem asterisk.key

# Generate new cert/key for localhost
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout asterisk.key \
  -out asterisk.pem \
  -subj "/C=IN/ST=State/L=City/O=MyAsterisk/CN=localhost"


to verify the certificate

` openssl x509 -in asterisk.pem -text -noout | grep -A2 "Subject Alternative Name"`



    
# MySQL Container
docker run -d \
    --name cts-mysql \
    --network cts-network \
    -e MYSQL_ROOT_PASSWORD=supersecretrootpassword \
    -e MYSQL_DATABASE=asterisk_db \
    -e MYSQL_USER=asterisk_user \
    -e MYSQL_PASSWORD=asterisk_password \
    --restart always \
    -v mysql_data:/var/lib/mysql \
    cts-mysql


# Frontend Container
docker run -d \
    --name cts-frontend \
    --network cts-network \
    -p 5000:5000 \
    -e DB_HOST=cts-mysql \
    -e DB_NAME=asterisk_db \
    -e DB_USER=asterisk_user \
    -e DB_PASSWORD=asterisk_password \
    --restart always \
    -v frontend_logs:/var/log/frontend \
    -v "$(pwd)/asterisk_recordings:/recordings" \
    cts-frontend

# Asterisk Container

docker run -d \
    --name cts-asterisk \
    --network cts-network \
    -p 5038:5038 \
    -p 5060:5060/udp \
    -p 5061:5061/tcp \
    -p 8088:8088 \
    -p 8089:8089 \
    -p 10000-10020:10000-10020/udp \
    --restart always \
    -v asterisk_conf:/etc/asterisk \
    -v asterisk_lib:/var/lib/asterisk \
    -v asterisk_log:/var/log/asterisk \
    -v asterisk_spool:/var/spool/asterisk \
    -v "$(pwd)/asterisk_recordings:/var/spool/asterisk/monitor" \
   cts-asterisk

 
  docker build --no-cache -t cts-asterisk .

  docker build -t cts-frontend .    


bash ./start.sh
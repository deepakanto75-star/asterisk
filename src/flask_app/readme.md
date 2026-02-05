# First create network for once

docker network create asterisk-net

# Docker build command

docker build -t my-flask-app .

# Docker run command

docker run -d --name flask_caller_app --network asterisk-net -e AMI_HOST=asterisk_server -e AMI_USERNAME=flaskuser -e AMI_SECRET=flasksecret -p 5000:5000 my-flask-app
    
    
# Docker container delete and image build container rerun command

docker rm -f flask_caller_app && docker build -t my-flask-app . && docker run -d --name flask_caller_app --network asterisk-net -e AMI_HOST=asterisk_server -e AMI_USERNAME=flaskuser -e AMI_SECRET=flasksecret -p 5000:5000 my-flask-app

#!/bin/bash

# -------------------------------
# Load Environment Variables
# -------------------------------
source .env

LOGS_FOLDER="/var/log/shell-project"
LOGS_FILE="$LOGS_FOLDER/project.log"
START_TIME=$(date +%s)

mkdir -p "$LOGS_FOLDER"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

echo "$(date "+%Y-%m-%d %H:%M:%S") | Script Execution Started" | tee -a "$LOGS_FILE"

# -------------------------------
# Input Validation
# -------------------------------
if [ -z "$1" ]; then
  echo -e "$R Usage: $0 {database|backend|frontend} $N"
  exit 1
fi

ROLE=$1

echo "Executing Role: $ROLE" | tee -a "$LOGS_FILE"

# -------------------------------
# Common Functions
# -------------------------------
validate(){
    if [ $1 -ne 0 ]; then
       echo -e "$2 ... $R FAILED $N"
       exit 1
    else
       echo -e "$2 ... $G SUCCESS $N"
    fi
}

# -------------------------------
# DATABASE SETUP
# -------------------------------
if [ "$ROLE" == "database" ]; then

    dnf install mysql-server -y &>>"$LOGS_FILE"
    validate $? "Installing MySQL"

    systemctl enable mysqld &>>"$LOGS_FILE"
    systemctl start mysqld &>>"$LOGS_FILE"
    validate $? "Starting MySQL"

    # Safe Password Setup
    mysql -uroot -p"$MYSQL_PASSWORD" -e "SELECT 1" >/dev/null 2>&1

    if [ $? -ne 0 ]; then
        mysql --connect-expired-password -uroot <<EOF &>>"$LOGS_FILE"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF
        validate $? "Setting MySQL root password"
    else
        echo -e "$Y MySQL password already set, skipping $N"
    fi

    # Download Schema
    rm -rf /tmp/app &>>"$LOGS_FILE"
    git clone https://github.com/Ramakrishna90111/Project28--Job-Internship-Application-Tracker-.git /tmp/app &>>"$LOGS_FILE"
    validate $? "Cloning repo for schema"

    echo "Skipping schema load - handled by backend ORM"

    echo -e "$G DATABASE SETUP COMPLETED $N"

fi

# -------------------------------
# BACKEND SETUP
# -------------------------------
if [ "$ROLE" == "backend" ]; then

    dnf module disable nodejs -y &>>"$LOGS_FILE"
    dnf module enable nodejs:20 -y &>>"$LOGS_FILE"
    dnf install nodejs git -y &>>"$LOGS_FILE"
    validate $? "Installing NodeJS & Git"

    id project &>>"$LOGS_FILE" || useradd project &>>"$LOGS_FILE"
    validate $? "Ensuring project user"

    rm -rf /app
    mkdir /app

    rm -rf /tmp/app &>>"$LOGS_FILE"

    git clone https://github.com/Ramakrishna90111/Project28--Job-Internship-Application-Tracker-.git /tmp/app &>>"$LOGS_FILE"
    validate $? "Cloning repo"

    cp -r /tmp/app/backend/* /app/
    cd /app

    npm install -g typescript ts-node &>>"$LOGS_FILE"
    validate $? "Installing TypeScript globally"

    npm install &>>"$LOGS_FILE"
    validate $? "Installing backend dependencies"

    # Update DB connection
   sed -i "s/localhost/database.$DOMAIN_NAME/" /app/config/db.ts

    # Systemd Service
    cat <<EOF >/etc/systemd/system/backend.service
[Unit]
Description=Backend Service

[Service]
User=project
Environment=DB_HOST=database.$DOMAIN_NAME
ExecStart=/usr/bin/node /app/index.js
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable backend &>>"$LOGS_FILE"
    systemctl start backend &>>"$LOGS_FILE"
    validate $? "Starting backend service"

    echo -e "$G BACKEND SETUP COMPLETED $N"

fi

# -------------------------------
# FRONTEND SETUP
# -------------------------------
# -------------------------------
# FRONTEND SETUP
# -------------------------------
if [ "$ROLE" == "frontend" ]; then

    # Install Nginx + NodeJS
    dnf install nginx nodejs -y &>>"$LOGS_FILE"
    validate $? "Installing Nginx & NodeJS"

    systemctl enable nginx &>>"$LOGS_FILE"
    systemctl start nginx &>>"$LOGS_FILE"
    validate $? "Starting Nginx"

    # Clean old files
    rm -rf /usr/share/nginx/html/*

    rm -rf /tmp/app &>>"$LOGS_FILE"

    # Clone repo
    git clone https://github.com/Ramakrishna90111/Project28--Job-Internship-Application-Tracker-.git /tmp/app &>>"$LOGS_FILE"
    validate $? "Cloning repo"

    # Go to frontend folder
    cd /tmp/app/frontend

    # Install dependencies
    npm install &>>"$LOGS_FILE"
    validate $? "Installing frontend dependencies"

    # Build project
    npm run build &>>"$LOGS_FILE"
    validate $? "Building frontend"

    # Copy build files to nginx
    cp -r dist/* /usr/share/nginx/html/
    validate $? "Copying build files"

    # Restart nginx
    systemctl restart nginx &>>"$LOGS_FILE"
    validate $? "Restarting Nginx"

    echo -e "$G FRONTEND SETUP COMPLETED $N"

fi

# -------------------------------
# TOTAL TIME
# -------------------------------
END_TIME=$(date +%s)
TOTAL_TIME=$(( END_TIME - START_TIME ))

echo -e "$(date "+%Y-%m-%d %H:%M:%S") | Script Executed in: $G $TOTAL_TIME seconds $N" | tee -a "$LOGS_FILE"
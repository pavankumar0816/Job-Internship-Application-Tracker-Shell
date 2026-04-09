#!/bin/bash

source .env

userid=$(id -u)
LOGS_FOLDER="/var/log/shell-project"
LOGS_FILE="$LOGS_FOLDER/$(basename $0).log"
START_TIME=$(date +%s)
SCRIPT_DIR=$PWD

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

mkdir -p "$LOGS_FOLDER"
echo "$(date "+%Y-%m-%d %H:%M:%S") | Script Execution Started" | tee -a "$LOGS_FILE"

 
check_root(){
    if [ "$userid" -ne 0 ]; then
        echo -e "$R Run using sudo access $N"
        exit 1
    fi
}

validate(){
    if [ $1 -ne 0 ]; then
       echo -e "$2 is $R Failed $N ..."
       exit 1
    else
       echo -e "$2 is $G Success $N ..."
    fi
}

print_total_time(){
    END_TIME=$(date +%s)
    TOTAL_TIME=$(( END_TIME - START_TIME ))
    echo -e "$(date "+%Y-%m-%d %H:%M:%S") | Script Executed in: $G $TOTAL_TIME seconds $N" | tee -a "$LOGS_FILE"
}

check_root

if [ -z "$MYSQL_PASSWORD" ]; then
    echo -e "$R MYSQL_PASSWORD not set in .env $N"
    exit 1
else
    echo -e "$G MYSQL_PASSWORD loaded from .env $N"
fi
 
if command -v node &>/dev/null && node -v | grep -q "^v20"; then
      echo -e "NodeJS 20 already installed $Y Skipping ... $N" | tee -a "$LOGS_FILE"
else
      dnf module disable nodejs -y &>>"$LOGS_FILE"
      validate $? "Disabling NodeJS module"

      dnf module enable nodejs:20 -y &>>"$LOGS_FILE"
      validate $? "Enabling NodeJS 20 module"

      dnf install nodejs -y &>>"$LOGS_FILE"
      validate $? "Installing NodeJS 20"
fi
 
dnf install git -y &>>"$LOGS_FILE"
validate $? "Installing git"

 
rm -rf /tmp/app-repo &>>"$LOGS_FILE"
git clone https://github.com/Ramakrishna90111/Project28--Job-Internship-Application-Tracker-.git /tmp/app-repo &>>"$LOGS_FILE"
validate $? "Cloning GitHub repo"

# -------------------------------
# Backend Setup
# -------------------------------
app_name=backend
id project &>>"$LOGS_FILE" || useradd project &>>"$LOGS_FILE"
validate $? "Ensuring project user exists"

mkdir -p /app
rm -rf /app/*
cp -r /tmp/app-repo/$app_name/* /app/
chown -R project:project /app
cd /app || exit 1
npm install &>>"$LOGS_FILE"
validate $? "Installing backend dependencies"

# systemd service
cp "$SCRIPT_DIR/$app_name.service" "/etc/systemd/system/$app_name.service" &>>"$LOGS_FILE"
validate $? "Copying systemd service file"

systemctl daemon-reload &>>"$LOGS_FILE"
systemctl enable $app_name &>>"$LOGS_FILE"
systemctl start $app_name &>>"$LOGS_FILE"
validate $? "Starting backend service"

# -------------------------------
# MySQL Setup
# -------------------------------
dnf install mysql-server -y &>>"$LOGS_FILE"
systemctl enable mysqld &>>"$LOGS_FILE"
systemctl start mysqld &>>"$LOGS_FILE"

mysql --connect-expired-password -uroot <<EOF &>>"$LOGS_FILE"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF
validate $? "Setting MySQL root password"

mysql -h localhost -uroot -p"$MYSQL_PASSWORD" < /app/schema/backend.sql &>>"$LOGS_FILE"
validate $? "Loading MySQL schema"

# -------------------------------
# Frontend Setup
# -------------------------------
app_name=frontend
dnf install nginx -y &>>"$LOGS_FILE"
validate $? "Installing Nginx"

systemctl enable nginx &>>"$LOGS_FILE"
systemctl start nginx &>>"$LOGS_FILE"
validate $? "Starting Nginx"

rm -rf /usr/share/nginx/html/*
cp -r /tmp/app-repo/$app_name/* /usr/share/nginx/html/
validate $? "Copying frontend code to Nginx html"

cp "$SCRIPT_DIR/expense.conf" /etc/nginx/default.d/expense.conf &>>"$LOGS_FILE"
validate $? "Copying Nginx config"

systemctl restart nginx &>>"$LOGS_FILE"
validate $? "Restarting Nginx"

 
print_total_time
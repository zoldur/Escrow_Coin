#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="Escrow.conf"
ESCROW_DAEMON="/usr/local/bin/Escrowd"
ESCROW_REPO="https://github.com/Escrow-Coin/EscrowCoinCore_Linux"
DEFAULTESCROWPORT=8018
DEFAULTESCROWUSER="escrow"
NODEIP=$(curl -s4 icanhazip.com)


RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $ESCROW_DAEMON)" ] || [ -e "$ESCROW_DAEMOM" ] ; then
  echo -e "${GREEN}\c"
  read -e -p "Escrow is already installed. Do you want to add another MN? [Y/N]" NEW_ESCROW
  echo -e "{NC}"
  clear
else
  NEW_ESCROW="new"
fi
}

function prepare_system() {

echo -e "Prepare the system to install Escrow master node."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget pwgen curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
libminiupnpc-dev libgmp3-dev ufw fail2ban >/dev/null 2>&1
clear
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git pwgen curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw fail2ban "
 exit 1
fi

clear
echo -e "Checking if swap space is needed."
PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
SWAP=$(free -g|awk '/^Swap:/{print $2}')
if [ "$PHYMEM" -lt "2" ] && [ -n "$SWAP" ]
  then
    echo -e "${GREEN}Server is running with less than 2G of RAM without SWAP, creating 2G swap file.${NC}"
    SWAPFILE=$(mktemp)
    dd if=/dev/zero of=$SWAPFILE bs=1024 count=2M
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon -a $SWAPFILE
else
  echo -e "${GREEN}Server running with at least 2G of RAM, no swap needed.${NC}"
fi
clear
}

function compile_node() {
  echo -e "Clone git repo and compile it. This may take some time. Press a key to continue."
  cd $TMP_FOLDER
  git clone $ESCROW_REPO
  cd EscrowCoinCore_Linux/src
  make -f makefile.unix
  compile_error Escrow 
  chmod +x  Escrowd
  cp -a  Escrowd /usr/local/bin
  clear
  cd ~
  rm -rf $TMP_FOLDER
}

function enable_firewall() {
  echo -e "Installing fail2ban and setting up firewall to allow ingress on port ${GREEN}$ESCROWPORT${NC}"
  ufw allow $ESCROWPORT/tcp comment "ESCROW MN port" >/dev/null
  ufw allow $[ESCROWPORT-1]/tcp comment "ESCROW RPC port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl start fail2ban >/dev/null 2>&1
}

function configure_systemd() {
  cat << EOF > /etc/systemd/system/$ESCROWUSER.service
[Unit]
Description=ESCROW service
After=network.target

[Service]
ExecStart=$ESCROW_DAEMON -conf=$ESCROWFOLDER/$CONFIG_FILE -datadir=$ESCROWFOLDER
ExecStop=$ESCROW_DAEMON -conf=$ESCROWFOLDER/$CONFIG_FILE -datadir=$ESCROWFOLDER stop
Restart=on-abort
User=$ESCROWUSER
Group=$ESCROWUSER

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $ESCROWUSER.service
  systemctl enable $ESCROWUSER.service

  if [[ -z "$(ps axo user:15,cmd:100 | egrep ^$ESCROWUSER | grep $ESCROW_DAEMON)" ]]; then
    echo -e "${RED}ESCROW is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $ESCROWUSER.service"
    echo -e "systemctl status $ESCROWUSER.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}

function ask_port() {
read -p "Escrow Port: " -i $DEFAULTESCROWPORT -e ESCROWPORT
: ${ESCROWPORT:=$DEFAULTESCROWPORT}
}

function ask_user() {
  read -p "Escrow user: " -i $DEFAULTESCROWUSER -e ESCROWUSER
  : ${ESCROWUSER:=$DEFAULTESCROWUSER}

  if [ -z "$(getent passwd $ESCROWUSER)" ]; then
    USERPASS=$(pwgen -s 12 1)
    useradd -m $ESCROWUSER
    echo "$ESCROWUSER:$USERPASS" | chpasswd

    ESCROWHOME=$(sudo -H -u $ESCROWUSER bash -c 'echo $HOME')
    DEFAULTESCROWFOLDER="$ESCROWHOME/.Escrow"
    read -p "Configuration folder: " -i $DEFAULTESCROWFOLDER -e ESCROWFOLDER
    : ${ESCROWFOLDER:=$DEFAULTESCROWFOLDER}
    mkdir -p $ESCROWFOLDER
    chown -R $ESCROWUSER: $ESCROWFOLDER >/dev/null
  else
    clear
    echo -e "${RED}User exits. Please enter another username: ${NC}"
    ask_user
  fi
}

function check_port() {
  declare -a PORTS
  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $ESCROWPORT ]] || [[ ${PORTS[@]} =~ $[ESCROWPORT-1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function create_config() {
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $ESCROWFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$[ESCROWPORT-1]
listen=1
server=1
daemon=1
port=$ESCROWPORT
EOF
}

function create_key() {
  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -e ESCROWKEY
  if [[ -z "$ESCROWKEY" ]]; then
  su $ESCROWUSER -c "$ESCROW_DAEMON -conf=$ESCROWFOLDER/$CONFIG_FILE -datadir=$ESCROWFOLDER"
  sleep 5
  if [ -z "$(ps axo user:15,cmd:100 | egrep ^$ESCROWUSER | grep $ESCROW_DAEMON)" ]; then
   echo -e "${RED}Escrow server couldn't start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  ESCROWKEY=$(su $ESCROWUSER -c "$ESCROW_DAEMON -conf=$ESCROWFOLDER/$CONFIG_FILE -datadir=$ESCROWFOLDER masternode genkey")
  su $ESCROWUSER -c "$ESCROW_DAEMON -conf=$ESCROWFOLDER/$CONFIG_FILE -datadir=$ESCROWFOLDER stop"
fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $ESCROWFOLDER/$CONFIG_FILE
  cat << EOF >> $ESCROWFOLDER/$CONFIG_FILE
maxconnections=256
masternode=1
masternodeaddr=$NODEIP:$ESCROWPORT
masternodeprivkey=$ESCROWKEY
EOF
  chown -R $ESCROWUSER: $ESCROWFOLDER >/dev/null
}

function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "Escrow Masternode is up and running as user ${GREEN}$ESCROWUSER${NC} and it is listening on port ${GREEN}$ESCROWPORT${NC}."
 echo -e "${GREEN}$ESCROWUSER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$ESCROWFOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $ESCROWUSER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $ESCROWUSER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODEIP:$ESCROWPORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$ESCROWKEY${NC}"
 echo -e "Please check Escrow is running with the following command: ${GREEN}systemctl status $ESCROWUSER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
  ask_user
  check_port
  create_config
  create_key
  update_config
  enable_firewall
  configure_systemd
  important_information
}


##### Main #####
clear

checks
if [[ ("$NEW_ESCROW" == "y" || "$NEW_ESCROW" == "Y") ]]; then
  setup_node
  exit 0
elif [[ "$NEW_ESCROW" == "new" ]]; then
  prepare_system
  compile_node
  setup_node
else
  echo -e "${GREEN}Escrow already running.${NC}"
  exit 0
fi


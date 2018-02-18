# Escrow Coin
Shell script to install an [Escrow Masternode](https://http://www.escrow-coin.com/) on a Linux server running Ubuntu 16.04. Use it on your own risk.  

***
## Installation:  

wget -q https://raw.githubusercontent.com/zoldur/Escrow_Coin/master/escrow_install.sh  
bash escrow_install.sh
***

## Desktop wallet setup  

After the MN is up and running, you need to configure the desktop wallet accordingly. Here are the steps:  
1. Open the Escros Desktop Wallet.  
2. Go to RECEIVE and create a New Address: **MN1**  
3. Send **1500** ESCO to **MN1**.  
4. Wait for 15 confirmations.  
5. Go to **Help -> "Debug window - Console"**  
6. Type the following command: **masternode outputs**  
7. Go to **Masternodes** tab  
8. Click **Create** and fill the details:  
* Alias: **MN1**  
* Address: **VPS_IP:PORT**  
* Privkey: **Masternode Private Key**  
* TxHash: **First value from Step 6**  
* Output index:  **Second value from Step 6**  
* Reward address: leave blank  
* Reward %: leave blank  
9. Click **OK** to add the masternode  
10. Click **Start All**  

***

## Multiple MN on one VPS:

It is possible to run multiple **Escrow** Master Nodes on the same VPS. Each MN will run under a different user you will choose during installation.  

***


## Usage:  

For security reasons **Escrow** is installed under **escrow** user, hence you need to **su - escrow** before checking:    

```
ESCROW_USER=escrow #replace escrow with the MN username you want to check

su - $ESCROW_USER  
Escrowd masternode status  
Escrowd getinfo  
```  

Also, if you want to check/start/stop **Escrow** , run one of the following commands as **root**:

```
ESCROW_USER=escrow  #replace escrow with the MN username you want to check  
  
systemctl status $ESCROW_USER #To check the service is running.  
systemctl start $ESCROW_USER #To start Escrow service.  
systemctl stop $AESCROW_USER #To stop Escrow service.  
systemctl is-enabled $ESCROW_USER #To check whetether Escrow service is enabled on boot or not.  
```  

***

  
Any donation is highly appreciated  

**ESCO**: EKFz9XSQp2z7pDvmaBfJFfsn5r4v3ifb8f  
**BTC**: 1BzeQ12m4zYaQKqysGNVbQv1taN7qgS8gY  
**ETH**: 0x39d10fe57611c564abc255ffd7e984dc97e9bd6d  
**LTC**: LXrWbfeejNQRmRvtzB6Te8yns93Tu3evGf  


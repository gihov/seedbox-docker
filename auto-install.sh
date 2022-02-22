#!/bin/bash

MEDIA_PASSWORD=password
DOCKER_USER=debian
PRIVATE_DOMAIN=domain.local
PUBLIC_DOMAIN=domain.tld
VPN_DOMAIN=vpn.domain2.tld
VPN_PORT=1194
OVH_APPLICATION_KEY=appkeyy
OVH_APPLICATION_SECRET=appsecret
OVH_CONSUMER_KEY=consumerkey

echo "[+] Log as sudo user"
sudo -i

echo "[+] Creating chrooted user"
mkdir -p /data/{Movies,Series}
mkdir -p /data/torrents/{downloads,incomplete,torrent_files}
groupadd sftp_users
adduser media --system --group --shell /usr/sbin/nologin
usermod media -G sftp_users
echo "media:${MEDIA_PASSWORD}" | chpasswd
chown -R media:media /data/{Movies,Series,torrents}
cp /etc/ssh/sshd_config /etc/ssh/sshd_config-org
sed 's/^Subsystem/#&/' -i  /etc/ssh/sshd_config
cat <<EOF >> /etc/ssh/sshd_config
Subsystem       sftp    internal-sftp

Match Group sftp_users
    X11Forwarding no
    AllowTcpForwarding no
    ChrootDirectory /data
    ForceCommand internal-sftp
EOF
systemctl restart sshd

echo "[+] Installing docker"
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install docker-ce docker-ce-cli containerd.io
usermod -aG docker debian

echo "[+] Adding docker group to ${DOCKER_USER}"
usermod -aG docker ${DOCKER_USER}

echo "[+] Creating users for seedbox services"
adduser vpn --system --no-create-home --group --shell /usr/sbin/nologin
adduser qbittorrent --system --no-create-home --group --shell /usr/sbin/nologin
adduser jackett --system --no-create-home --group --shell /usr/sbin/nologin
adduser radarr --system --no-create-home --group --shell /usr/sbin/nologin
adduser sonarr --system --no-create-home --group --shell /usr/sbin/nologin
adduser ombi --system --no-create-home --group --shell /usr/sbin/nologin
adduser jellyfin --system --no-create-home --group --shell /usr/sbin/nologin
usermod -aG media qbittorrent
usermod -aG media radarr
usermod -aG media sonarr
usermod -aG media jellyfin

echo "[+] Installing nginx"
apt install nginx nginx-extras -y
# Disable nginx version
sed -i '/tokens/s/#//g' /etc/nginx/nginx.conf

echo "[+] Installing certbot"
apt install python3 python3-venv libaugeas0 -y
python3 -m venv /opt/certbot/
/opt/certbot/bin/pip install --upgrade pip
/opt/certbot/bin/pip install certbot
/opt/certbot/bin/pip install certbot-dns-ovh
ln -s /opt/certbot/bin/certbot /usr/bin/certbot

echo "[+] Creating ovh config file"
mkdir -p /root/.secrets/certbot/
cat <<EOF > /root/.secrets/certbot/ovh.ini
# OVH API credentials used by Certbot
dns_ovh_endpoint = ovh-eu
dns_ovh_application_key = ${OVH_APPLICATION_KEY}
dns_ovh_application_secret = ${OVH_APPLICATION_SECRET}
dns_ovh_consumer_key = ${OVH_CONSUMER_KEY}
EOF
chmod 600 /root/.secrets/certbot/ovh.ini

echo "[+] Requesting certificates"
certbot certonly -m webmaster@${PRIVATE_DOMAIN} --dns-ovh-propagation-seconds 60 --dns-ovh --dns-ovh-credentials /root/.secrets/certbot/ovh.ini -d download.${PRIVATE_DOMAIN} --agree-tos --no-eff-email
certbot certonly -m webmaster@${PRIVATE_DOMAIN} --dns-ovh-propagation-seconds 60 --dns-ovh --dns-ovh-credentials /root/.secrets/certbot/ovh.ini -d jackett.${PRIVATE_DOMAIN} --agree-tos --no-eff-email
certbot certonly -m webmaster@${PRIVATE_DOMAIN} --dns-ovh-propagation-seconds 60 --dns-ovh --dns-ovh-credentials /root/.secrets/certbot/ovh.ini -d radarr.${PRIVATE_DOMAIN} --agree-tos --no-eff-email
certbot certonly -m webmaster@${PRIVATE_DOMAIN} --dns-ovh-propagation-seconds 60 --dns-ovh --dns-ovh-credentials /root/.secrets/certbot/ovh.ini -d sonarr.${PRIVATE_DOMAIN} --agree-tos --no-eff-email
certbot certonly -m webmaster@${PUBLIC_DOMAIN} --dns-ovh-propagation-seconds 60 --dns-ovh --dns-ovh-credentials /root/.secrets/certbot/ovh.ini -d media.${PUBLIC_DOMAIN} --agree-tos --no-eff-email

echo "[+] Setting up auto renew of certificates"
cat <<EOF > /etc/letsencrypt/cli.ini
deploy-hook = systemctl reload nginx
EOF
cat <<EOF >> /etc/crontab
0 1     14 * 0  root    /usr/bin/certbot renew --quiet
EOF

echo "[+] Creating config files for nginx"
cp -R ./seedbox-docker/nginx/ /etc/
find ./sites-available/ -type f -exec sed -i "s/PRIVATE_DOMAIN/${PRIVATE_DOMAIN}/g" {} +
find ./sites-available/ -type f -exec sed -i "s/PUBLIC_DOMAIN/${PUBLIC_DOMAIN}/g" {} +
ln -s /etc/nginx/sites-available/download.conf /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/jackett.conf /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/radarr.conf /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/sonarr.conf /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/media.conf /etc/nginx/sites-enabled/
nginx -s reload

echo "[+] Disconnect from sudo user"
exit
#####################################################################

echo "[+] Installing docker compose"
# For local user : ~/.docker/cli-plugins/
# For system-wide :
# /usr/local/lib/docker/cli-plugins/ OR /usr/local/libexec/docker/cli-plugins/
# /usr/lib/docker/cli-plugins/ OR /usr/libexec/docker/cli-plugins/
DOCKER_PATH=~/.docker/cli-plugins/
REPO="docker/compose"
# Get latest tag number
TAG=$(curl --silent "https://api.github.com/repos/${REPO}/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
# If local user create directory
mkdir -p ${DOCKER_PATH}
curl -sSL https://github.com/docker/compose/releases/download/${TAG}/docker-compose-linux-x86_64 -o ${DOCKER_PATH}/docker-compose
chmod +x ${DOCKER_PATH}/docker-compose
docker compose version

echo "[+] Creating directory and config files for seedbox services"
mkdir -p /home/${DOCKER_USER}/docker/{vpn,qbittorrent,jackett,radarr,sonarr,ombi,jellyfin}/config
cp -R ./seedbox-docker/docker/ /home/${DOCKER_USER}/

echo "[+] Creating vpn config files"
DOCKER_DIR=/home/${DOCKER_USER}/docker/
sed -i "s/VPN_DOMAIN/${VPN_DOMAIN}/g" ${DOCKER_DIR}/vpn/vpn.conf
sed -i "s/VPN_PORT/${VPN_PORT}/g" ${DOCKER_DIR}/vpn/vpn.conf

echo "[+] Setting .env variables"
ENV_FILE=${DOCKER_DIR}/.env
sed -i "s/vpn_user/$(id -u vpn)/g" ${ENV_FILE}
sed -i "s/vpn_group/$(id -g vpn)/g" ${ENV_FILE}
sed -i "s/qbittorrent_user/$(id -u qbittorrent)/g" ${ENV_FILE}
sed -i "s/jackett_user/$(id -u jackett)/g" ${ENV_FILE}
sed -i "s/jackett_group/$(id -g jackett)/g" ${ENV_FILE}
sed -i "s/radarr_user/$(id -u radarr)/g" ${ENV_FILE}
sed -i "s/sonarr_user/$(id -u sonarr)/g" ${ENV_FILE}
sed -i "s/ombi_user/$(id -u ombi)/g" ${ENV_FILE}
sed -i "s/ombi_group/$(id -g ombi)/g" ${ENV_FILE}
sed -i "s/jellyfin_user/$(id -u jellyfin)/g" ${ENV_FILE}
sed -i "s/media_group/$(id -g media)/g" ${ENV_FILE}
sed -i "s/DOCKER_USER/${DOCKER_USER}/g" ${ENV_FILE}
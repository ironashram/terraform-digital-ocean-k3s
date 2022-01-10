### terraform-digital-ocean-k3s + kilo example
# Deploy the vms, the terraform code in this repo requires a digital ocean account and k3sup but it's only an example

# deploy kilo, it needs to be the primary and possibly only CNI
```
kubectl apply -f https://raw.githubusercontent.com/squat/kilo/main/manifests/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/squat/kilo/main/manifests/kilo-k3s.yaml
```

# create key pair
```
wg genkey | tee privatekey | wg pubkey > publickey
```

# create the peer k8s object
```
cat <<'EOF' | kubectl apply -f -
apiVersion: kilo.squat.ai/v1alpha1
kind: Peer
metadata:
  name: vpn-client-1
spec:
  allowedIPs:
  - 10.5.0.1/32
  publicKey: publickey previously generated goes here
  persistentKeepalive: 10
EOF
```
# grab one of the k8s nodes wg public key
```
ssh k3s_tor1_agent wg show
interface: kilo0
  public key: somethingwhatever
  private key: (hidden)
  listening port: 51820
```

# create a wireguard config like the following
```
cat /etc/wireguard/wg0.conf
[Interface]
Address = 10.5.0.1/32
PrivateKey = privatekey previously generated goes here

[Peer]
AllowedIPs = 10.4.0.0/24 # this is the internal network of the nodes
Endpoint = public_ip_of_k3s_tor1_agent_here:51820
PersistentKeepalive = 10
PublicKey = somethingwhatever
```

# bring up the link
```
sudo wg-quick up wg0
```
# check route
```
ip route get 10.4.0.0
10.4.0.0 dev wg0 src 10.5.0.1 uid 1000
    cache
```
# test connectivity
```
ping 10.4.0.1
PING 10.4.0.1 (10.4.0.1) 56(84) bytes of data.
64 bytes from 10.4.0.1: icmp_seq=1 ttl=64 time=125 ms
64 bytes from 10.4.0.1: icmp_seq=2 ttl=64 time=125 ms
```

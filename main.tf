
resource "digitalocean_ssh_key" "default" {
  name       = "m1k"
  public_key =  "${trimspace(file(var.ssh_pub_key_path))}"
}

resource "digitalocean_droplet" "k3s_fra1_master" {
  image     = "ubuntu-20-04-x64"
  name      = "ubuntu-s-2vcpu-4gb-fra1-01"
  region    = "fra1"
  size      = "s-2vcpu-4gb"
  ssh_keys  = [digitalocean_ssh_key.default.fingerprint]
  provisioner "remote-exec" {
    connection {
      host = "${self.ipv4_address}"
      user = "root"
      private_key = file("${var.ssh_priv_key_path}")
    }
    inline = ["echo '${self.name} is reachable via ssh!'"]
  }
  provisioner "local-exec" {
    command = <<EOT
            k3sup install \
            --ip ${self.ipv4_address} \
            --context k3s \
            --ssh-key ${var.ssh_priv_key_path} \
            --user root \
            --k3s-extra-args '--node-ip=${self.ipv4_address} --flannel-backend=none --disable-network-policy --disable traefik'
        EOT
  }
}

resource "digitalocean_droplet" "k3s_tor1_agent" {
  image     = "ubuntu-20-04-x64"
  name      = "ubuntu-s-1vcpu-1gb-tor1-01"
  region    = "tor1"
  size      = "s-1vcpu-1gb"
  ssh_keys  = [digitalocean_ssh_key.default.fingerprint]
  provisioner "remote-exec" {
    connection {
      host = "${self.ipv4_address}"
      user = "root"
      private_key = file("${var.ssh_priv_key_path}")
    }
    inline = ["echo '${self.name} is reachable via ssh!'"]
  }
  provisioner "local-exec" {
    command = <<EOT
            k3sup join \
            --ip ${self.ipv4_address} \
            --server-ip ${digitalocean_droplet.k3s_fra1_master.ipv4_address} \
            --ssh-key ${var.ssh_priv_key_path} \
            --user root
        EOT
  }
}

resource "digitalocean_droplet" "k3s_sfo3_agent" {
  image     = "ubuntu-20-04-x64"
  name      = "ubuntu-s-1vcpu-1gb-sfo3-01"
  region    = "sfo3"
  size      = "s-1vcpu-1gb"
  ssh_keys  = [digitalocean_ssh_key.default.fingerprint]
  provisioner "remote-exec" {
    connection {
      host = "${self.ipv4_address}"
      user = "root"
      private_key = file("${var.ssh_priv_key_path}")
    }
    inline = ["echo '${self.name} is reachable via ssh!'"]
  }
  provisioner "local-exec" {
    command = <<EOT
            k3sup join \
            --ip ${self.ipv4_address} \
            --server-ip ${digitalocean_droplet.k3s_fra1_master.ipv4_address} \
            --ssh-key ${var.ssh_priv_key_path} \
            --user root
        EOT
  }
}

resource "null_resource" "make_ssh_config" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = <<COMMAND
cat <<SSHCONFIG > ~/.ssh/config.d/k3s
Host k3s_fra1_master
  User root
  HostName ${digitalocean_droplet.k3s_fra1_master.ipv4_address}
  IdentityFile ${var.ssh_priv_key_path}
Host k3s_tor1_agent
  User root
  HostName ${digitalocean_droplet.k3s_tor1_agent.ipv4_address}
  IdentityFile ${var.ssh_priv_key_path}
Host k3s_sfo3_agent
  User root
  HostName ${digitalocean_droplet.k3s_sfo3_agent.ipv4_address}
  IdentityFile ${var.ssh_priv_key_path}
SSHCONFIG
COMMAND
  }
}

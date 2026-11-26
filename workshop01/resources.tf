locals {
  name_prefix   = var.app_namespace == "" ? "" : "${var.app_namespace}-"
  backend_ports = docker_container.bgg-backend[*].ports[0].external
}

resource "docker_image" "bgg-database" {
  name = "chukmunnlee/bgg-database:${var.database_version}"
}

resource "docker_image" "bgg-backend" {
  name = "chukmunnlee/bgg-backend:${var.backend_version}"
}

resource "docker_network" "bgg-net" {
  name = "${local.name_prefix}bgg-net"
}

resource "docker_volume" "data-vol" {
  name = "${local.name_prefix}data-vol"
}

resource "docker_container" "bgg-database" {
  name  = "${local.name_prefix}bgg-database"
  image = docker_image.bgg-database.image_id

  networks_advanced {
    name = docker_network.bgg-net.name
  }

  volumes {
    volume_name    = docker_volume.data-vol.name
    container_path = "/var/lib/mysql"
  }

  ports {
    internal = 3306
    external = 3306
    ip       = "127.0.0.1"
  }
}

resource "docker_container" "bgg-backend" {
  count = var.backend_instance_count
  name  = "${local.name_prefix}bgg-backend-${count.index}"
  image = docker_image.bgg-backend.image_id

  networks_advanced {
    name = docker_network.bgg-net.name
  }

  env = [
    "BGG_DB_USER=root",
    "BGG_DB_PASSWORD=changeit",
    "BGG_DB_HOST=${docker_container.bgg-database.name}",
  ]

  ports {
    internal = 3000
  }
}

resource "local_file" "nginx-conf" {
  filename        = "${path.module}/nginx.conf"
  file_permission = "0644"
  content = templatefile("${path.module}/sample.nginx.conf.tftpl", {
    docker_host = var.docker_host
    ports       = local.backend_ports
  })
}

data "digitalocean_ssh_key" "www-1" {
  name = var.do_ssh_key
}

resource "digitalocean_droplet" "nginx" {
  name     = "nginx"
  image    = var.do_image
  region   = var.do_region
  size     = var.do_size
  ssh_keys = [data.digitalocean_ssh_key.www-1.id]

  connection {
    type        = "ssh"
    user        = "root"
    host        = self.ipv4_address
    private_key = file(pathexpand(var.ssh_private_key))
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "cloud-init status --wait",
      "export DEBIAN_FRONTEND=noninteractive",
      "apt update -y",
      "apt -o Dpkg::Options::=--force-confold upgrade -y",
      "apt install nginx -y",
      "systemctl start nginx",
      "systemctl enable nginx",
    ]
  }
}

resource "terraform_data" "configure_proxy" {
  triggers_replace = [digitalocean_droplet.nginx.id, local_file.nginx-conf.content_sha256]

  connection {
    type        = "ssh"
    user        = "root"
    host        = digitalocean_droplet.nginx.ipv4_address
    private_key = file(pathexpand(var.ssh_private_key))
  }

  provisioner "file" {
    source      = local_file.nginx-conf.filename
    destination = "/root/workshop-nginx.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "nginx -t -c /root/workshop-nginx.conf",
      "install -m 0644 /root/workshop-nginx.conf /etc/nginx/nginx.conf",
      "systemctl reload nginx",
      "systemctl is-active --quiet nginx",
    ]
  }
}

resource "local_file" "root_at_nginx" {
  filename        = "${path.module}/root@${digitalocean_droplet.nginx.ipv4_address}"
  content         = ""
  file_permission = "0444"
  depends_on      = [terraform_data.configure_proxy]
}

output "nginx_ip" {
  value      = digitalocean_droplet.nginx.ipv4_address
  depends_on = [terraform_data.configure_proxy]
}

output "backend_ports" {
  value = local.backend_ports
}

output "backend_endpoints" {
  value = [for port in local.backend_ports : "${var.docker_host}:${port}"]
}

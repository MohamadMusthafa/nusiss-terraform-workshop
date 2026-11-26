# Workshop 01 · Boardgame Search

Terraform provisions the `bgg-net` Docker network, a persistent MySQL container, three BGG backends and an Nginx reverse proxy on a separate DigitalOcean Droplet. Docker assigns each backend a host port. Terraform uses those ports to generate the proxy's least-connections upstream.

## Set up the controller and Docker host

The course starts with an Ubuntu 22.04 x64 controller in Singapore. The verified run reused the group's existing Ubuntu 24.04 controller and created two Droplets, one for Docker and one for Nginx. Follow steps 3–10 on the controller to register its public SSH key as `www-1` and install Terraform, Docker Engine and Docker Machine. [Course setup](https://github.com/kenken64/NUSISS-DevSecOpsEng/blob/master/workshop/workshop3-1.md#solution) · [Docker Engine apt installation](https://docs.docker.com/engine/install/ubuntu/#install-using-the-apt-repository)

The guide's regular Droplet sizes were unavailable in Singapore during this run. To reproduce it, set the course's `DO_PAT` in the controller shell and use the Intel size for both hosts. Run this command once to create the Docker host.

```bash
export DIGITALOCEAN_ACCESS_TOKEN="${DO_PAT:?Set DO_PAT on the controller}"
docker-machine create \
  --driver digitalocean \
  --digitalocean-image ubuntu-24-04-x64 \
  --digitalocean-region sgp1 \
  --digitalocean-size s-1vcpu-1gb-intel \
  --digitalocean-backups=false \
  docker-nginx
```

## Deploy from the controller

From this directory on the controller, with the course's `DO_PAT` set in the shell, run the following commands. Adjust the private-key path if you chose a different filename for the key registered as `www-1`.

```bash
export TF_VAR_do_token="${DO_PAT:?Set DO_PAT on the controller}"
export TF_VAR_do_size="s-1vcpu-1gb-intel"
export TF_VAR_docker_host="$(docker-machine ip docker-nginx)"
export TF_VAR_docker_cert_path="$HOME/.docker/machine/machines/docker-nginx"
export TF_VAR_ssh_private_key="$HOME/.ssh/id_rsa"

terraform init
terraform validate
terraform plan -out=workshop.tfplan
terraform apply workshop.tfplan
terraform output
```

The default network and database names match the assignment. Set `TF_VAR_app_namespace=my` before planning to use the prefix in the worked example. The proxy defaults to the worked example's Ubuntu 24.04 x64 image. The backends reach MySQL on port 3306 over `bgg-net`. The Docker host also publishes that port on loopback.

## Check the deployment

Open the URL printed below. The expected page shows **Boardgame Search** and a field labeled **Enter boardgame name**. Search for a game to exercise the database connection.

```bash
proxy_ip="$(terraform output -raw nginx_ip)"
printf 'http://%s/\n' "$proxy_ip"
terraform output backend_endpoints
cat nginx.conf
test -f "root@$proxy_ip" && test ! -s "root@$proxy_ip" && echo "Empty SSH marker verified"
```

`backend_endpoints` lists one Docker host address and port per backend. The generated `nginx.conf` should contain the same three endpoints. The empty `root@<proxy-ip>` file is created when the proxy configuration has been installed and reloaded.

The verified deployment had three backends. A search through the Nginx proxy returned **Gloomhaven**, game ID `174430`.

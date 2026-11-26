variable "do_token" {
  type      = string
  sensitive = true
}

variable "docker_host" {
  description = "Public IPv4 address of the docker-nginx Docker Machine."
  type        = string
}

variable "docker_cert_path" {
  description = "Docker Machine directory containing ca.pem, cert.pem and key.pem."
  type        = string
  sensitive   = true
}

variable "app_namespace" {
  description = "Optional prefix for Docker resource names. The worked example uses my."
  type        = string
  default     = ""
}

variable "database_version" {
  type    = string
  default = "v3.1"
}

variable "backend_version" {
  type    = string
  default = "v3"
}

variable "backend_instance_count" {
  type    = number
  default = 3

  validation {
    condition     = var.backend_instance_count >= 1 && floor(var.backend_instance_count) == var.backend_instance_count
    error_message = "Select a positive integer so the proxy has at least one backend."
  }
}

variable "do_region" {
  type    = string
  default = "sgp1"
}

variable "do_image" {
  type    = string
  default = "ubuntu-24-04-x64"
}

variable "do_size" {
  type    = string
  default = "s-1vcpu-512mb-10gb"
}

variable "do_ssh_key" {
  type    = string
  default = "www-1"
}

variable "ssh_private_key" {
  description = "Path to the private key matching the www-1 public key on DigitalOcean."
  type        = string
}

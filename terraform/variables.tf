variable "username" {}
variable "password" {}
variable "tenant_name" {}
variable "auth_url" {}
variable "public_key" {}
variable "user_login" {
    default = "stack"
}
variable "key_file_path" {}

variable "nb_of_nodes" {
    default = "4"
}

variable "pub_net_id" {
    default = {
         RegionOne="admin_floating_net"
         tr2-1 = ""
    }
}

variable "region" {
    default = "RegionOne"
    description = "The region of openstack, for image/flavor/network lookups."
}

variable "image" {
    default = {
         RegionOne = "889c3d61-9761-48c4-b2aa-07ba1d930728"
         tr2-1 = ""
    }
}

variable "flavor" {
    default = {
         RegionOne = "4df1d502-7dea-4cf0-9f36-e4de464678a7"
         tr2-1 = ""
    }
}

variable "servers" {
    default = "3"
    description = "The number of Consul servers to launch."
}

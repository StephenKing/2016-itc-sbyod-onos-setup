provider "openstack" {
    user_name  = "${var.username}"
    tenant_name = "${var.tenant_name}"
    password  = "${var.password}"
    auth_url  = "${var.auth_url}"
}

resource "openstack_compute_keypair_v2" "sbyod_keypair" {
  name = "sbyod-keypair"
  region = "${var.region}"
  public_key = "${var.public_key}"
}
resource "openstack_compute_secgroup_v2" "allow_all" {
  name = "allow_all"
  description = "Allow all"
  rule {
    ip_protocol = "tcp"
    from_port = 1
    to_port = 65535
    cidr = "0.0.0.0/0"
  }
  rule {
    ip_protocol = "udp"
    from_port = 1
    to_port = 65535
    cidr = "0.0.0.0/0"
  }
  rule {
    ip_protocol = "icmp"
    from_port = -1
    to_port = -1
    cidr = "0.0.0.0/0"
  }
}

###############################
# Consul
###############################

# resource "openstack_compute_floatingip_v2" "consul_ip" {
#   region = "${var.region}"
#   pool = "${lookup(var.pub_net_id, var.region)}"
#   count = "${var.servers}"
# }

resource "openstack_compute_instance_v2" "consul_node" {
  name = "consul-${count.index}"
  region = "${var.region}"
  image_id = "${lookup(var.image, var.region)}"
  flavor_id = "${lookup(var.flavor, var.region)}"
  # floating_ip = "${element(openstack_compute_floatingip_v2.consul_ip.*.address,count.index)}"
  key_pair = "sbyod-keypair"
  count = "${var.servers}"

  network {
    name = "admin_internal_net"
  }
  security_groups = ["${openstack_compute_secgroup_v2.allow_all.name}"]

    connection {
        user = "${var.user_login}"
        key_file = "${var.key_file_path}"
        timeout = "1m"
    }

    provisioner "file" {
        source = "${path.module}/consul/upstart.conf"
        destination = "/tmp/upstart.conf"
    }

    provisioner "file" {
        source = "${path.module}/consul/upstart-join.conf"
        destination = "/tmp/upstart-join.conf"
    }

    provisioner "remote-exec" {
        inline = [
            "echo ${var.servers} > /tmp/consul-server-count",
            "echo ${count.index} > /tmp/consul-server-index",
            "echo ${openstack_compute_instance_v2.consul_node.0.network.0.fixed_ip_v4} > /tmp/consul-server-addr",
        ]
    }

    provisioner "remote-exec" {
        scripts = [
            "${path.module}/consul/install.sh",
            "${path.module}/consul/server.sh",
            "${path.module}/consul/service.sh",
        ]
    }
}

###############################
# Nginx
###############################

resource "openstack_compute_floatingip_v2" "nginx_template_ip" {
  region = "${var.region}"
  pool = "${lookup(var.pub_net_id, var.region)}"
}



resource "openstack_compute_instance_v2" "nginx_template_node" {
  name = "nginx-template"
  region = "${var.region}"
  image_id = "${lookup(var.image, var.region)}"
  flavor_id = "${lookup(var.flavor, var.region)}"
  floating_ip = "${openstack_compute_floatingip_v2.nginx_template_ip.address}"
  key_pair = "sbyod-keypair"
  network {
    name = "admin_internal_net"
  }
  security_groups = ["${openstack_compute_secgroup_v2.allow_all.name}"]


  metadata {
    consul_ip = "${openstack_compute_instance_v2.consul_node.0.network.0.fixed_ip_v4}"
  }

    connection {
        user = "${var.user_login}"
        key_file = "${var.key_file_path}"
        timeout = "1m"
    }

    provisioner "file" {
        source = "${path.module}/nginx/upstart-consul-agent.conf"
        destination = "/tmp/upstart-join.conf"
    }

    provisioner "file" {
        source = "${path.module}/nginx/consul-services.json"
        # we can't put the file into the final place, as we have to read our own
        # floating IP later when we boot that image in the ASG
        destination = "/tmp/services.json.dist"
    }

    provisioner "remote-exec" {
         scripts = [
             "${path.module}/nginx/install.sh",
             "${path.module}/nginx/install-consul.sh",
         ]
     }

     provisioner "remote-exec" {
         inline = [
             "sudo start consul-join",
         ]
     }
}

###############################
# Portal
###############################

resource "openstack_compute_floatingip_v2" "portal" {
  region = "${var.region}"
  pool = "${lookup(var.pub_net_id, var.region)}"
}

resource "openstack_compute_instance_v2" "portal" {
  name = "portal"
  region = "${var.region}"
  image_id = "${lookup(var.image, var.region)}"
  # flavor_id = "${lookup(var.flavor, var.region)}"
  flavor_id = 2 # needs a bit more than 512MB RAM
  floating_ip = "${openstack_compute_floatingip_v2.portal.address}"
  key_pair = "sbyod-keypair"
  network {
    name = "admin_internal_net"
  }
  security_groups = ["${openstack_compute_secgroup_v2.allow_all.name}"]

  metadata {
    consul_ip = "${openstack_compute_instance_v2.consul_node.0.network.0.fixed_ip_v4}"
  }

  connection {
    user = "${var.user_login}"
    key_file = "${var.key_file_path}"
    timeout = "1m"
  }

  provisioner "file" {
    source = "portal/upstart-meteorjs.conf"
    destination = "/tmp/upstart-meteorjs.conf"
  }

  provisioner "file" {
    source = "portal/nginx-site.conf"
    destination = "/tmp/nginx-site.conf"
  }

  provisioner "remote-exec" {
    script = "portal/install.sh"
  }
}


###############################
# VPN
###############################

resource "openstack_compute_floatingip_v2" "vpn" {
  region = "${var.region}"
  pool = "${lookup(var.pub_net_id, var.region)}"
}

resource "openstack_compute_instance_v2" "vpn" {
  name = "vpn"
  region = "${var.region}"
  image_id = "${lookup(var.image, var.region)}"
  flavor_id = "${lookup(var.flavor, var.region)}"
  floating_ip = "${openstack_compute_floatingip_v2.vpn.address}"
  key_pair = "sbyod-keypair"
  network {
    name = "admin_internal_net"
  }
  security_groups = ["${openstack_compute_secgroup_v2.allow_all.name}"]
  connection {
    user = "${var.user_login}"
    key_file = "${var.key_file_path}"
    timeout = "1m"
  }
  provisioner "remote-exec" {
    scripts = [
      "portal/install.sh",
      "portal/service.sh",
    ]
  }
}


/*
###############################
# ONOS
###############################

resource "openstack_compute_floatingip_v2" "onos_ip" {
  region = "${var.region}"
  pool = "${lookup(var.pub_net_id, var.region)}"
}

resource "openstack_compute_instance_v2" "onos_node" {
  name = "onos"
  region = "${var.region}"
  image_id = "${lookup(var.image, var.region)}"
  flavor_id = "${lookup(var.flavor, var.region)}"
  floating_ip = "${openstack_compute_floatingip_v2.onos_ip.address}"
  key_pair = "sbyod-keypair"

    connection {
        user = "${var.user_login}"
        key_file = "${var.key_file_path}"
        timeout = "1m"
    }

    provisioner "file" {
        source = "${path.module}/onos/upstart.conf"
        destination = "/tmp/upstart.conf"
    }

    provisioner "remote-exec" {
         scripts = [
             "${path.module}/onos/install.sh",
             "${path.module}/onos/service.sh",
         ]
     }
}

*/
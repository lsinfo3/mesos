# Configure the OpenStack Provider

variable os_user {
  description = "LDAP username"
}
variable os_password {
  description = "LDAP password (shown in plain-text!)"
}
variable os_project {
  default = "mesos"
  description = "OpenStack Project"
}

variable mesos_slave_count {
  default = 5
  description = "Number of Mesos Slaves"
}

provider "openstack" {
    user_name  = "${var.os_user}"
    tenant_name = "${var.os_project}"
    password  = "${var.os_password}"
    domain_name = "lsinfo3"
    auth_url  = "https://172.17.0.3:5000/v3"
    insecure = "true"
}

resource "openstack_compute_keypair_v2" "terraform" {
    name = "terraform"
    public_key = "${file("~/.ssh/id_rsa.pub")}"
}

#resource "openstack_blockstorage_volume_v1" "my_vol" {
#    name = "cs-tf-my_volume"
#    size = "10"
#}

resource "openstack_networking_network_v2" "network_1" {
  name = "cs-tf-network_1"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet_1" {
  name = "subnet_1"
  network_id = "${openstack_networking_network_v2.network_1.id}"
  cidr = "192.168.1.0/24"
  ip_version = 4
  dns_nameservers = ["132.187.0.13"]
}

resource "openstack_networking_port_v2" "port_1" {
  name = "port_1"
  network_id = "${openstack_networking_network_v2.network_1.id}"
  admin_state_up = "true"
}

resource "openstack_networking_router_v2" "router_1" {
  region = "RegionOne"
  name = "cs_tf_router"
  external_gateway = "753af3b7-49ff-4522-b3a8-0cf85d66b0ff"
}

resource "openstack_networking_router_interface_v2" "router_interface_1" {
  region = ""
  router_id = "${openstack_networking_router_v2.router_1.id}"
  subnet_id = "${openstack_networking_subnet_v2.subnet_1.id}"
}

resource "openstack_compute_secgroup_v2" "secgroup_1" {
  name = "cs_tf_secgroup_1"
  description = "Allow SSH and HTTP"
  rule {
    from_port = 22
    to_port = 22
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 1024
    to_port = 65535
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = -1
    to_port = -1
    ip_protocol = "icmp"
    cidr = "0.0.0.0/0"
  }
}

resource "openstack_compute_floatingip_v2" "floatip" {
  pool = "net04_ext"
  count = 7
}

resource "openstack_compute_instance_v2" "mesos-master" {
  count = 1

  name = "mesos-master-${count.index + 1}"
  floating_ip = "${element(openstack_compute_floatingip_v2.floatip.*.address, var.mesos_slave_count + count.index)}"

	image_name = "ubuntu14.04-x64"
	flavor_name = "m1.large"
	security_groups = ["cs_tf_secgroup_1"]
	region = "RegionOne"
  key_pair = "${openstack_compute_keypair_v2.terraform.name}"

  network {
    uuid = "${openstack_networking_network_v2.network_1.id}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/chef/trusted_certs/",
      "sudo chmod 777 /etc/chef/trusted_certs"
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "file" {
    source = "zeus_informatik_uni-wuerzburg_de.crt"
    destination = "/etc/chef/trusted_certs/zeus_informatik_uni-wuerzburg_de.crt"

    connection {
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "chef" {
    node_name = "mesos-master-${count.index + 1}"
    run_list = ["role[ls3-mesos-master]", "recipe[host-mesos-master]"]

    environment = "_default"
    connection {
      type = "ssh"
      user = "ubuntu"
    }
    server_url = "https://zeus.informatik.uni-wuerzburg.de/organizations/ls3"
    validation_client_name = "cschwartz"
    validation_key = "${file("../../ls3-chef-repo/.chef/client.pem")}"
    version = "12.5.1"
    ohai_hints = ["openstack.json"]
    ssl_verify_mode = ":verify_none"
  }
}

/*
resource "openstack_compute_instance_v2" "mesos-marathon" {
  count = 1

  name = "mesos-marathon"
  floating_ip = "${element(openstack_compute_floatingip_v2.floatip.*.address, var.mesos_slave_count + 1 + 1)}"

	image_name = "ubuntu14.04-x64"
	flavor_name = "m1.small"
	security_groups = ["cs_tf_secgroup_1"]
	region = "RegionOne"
  key_pair = "${openstack_compute_keypair_v2.terraform.name}"

  network {
    uuid = "${openstack_networking_network_v2.network_1.id}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/chef/trusted_certs/",
      "sudo chmod 777 /etc/chef/trusted_certs"
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "file" {
    source = "zeus_informatik_uni-wuerzburg_de.crt"
    destination = "/etc/chef/trusted_certs/zeus_informatik_uni-wuerzburg_de.crt"

    connection {
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "chef" {
    node_name = "marathon"
    run_list = ["recipe[host-marathon]"]

    environment = "_default"
    connection {
      type = "ssh"
      user = "ubuntu"
    }
    server_url = "https://zeus.informatik.uni-wuerzburg.de/organizations/ls3"
    validation_client_name = "cschwartz"
    validation_key = "${file("../../ls3-chef-repo/.chef/client.pem")}"
    version = "12.5.1"
    ohai_hints = ["openstack.json"]
    ssl_verify_mode = ":verify_none"
  }
}*/

resource "openstack_compute_instance_v2" "mesos-slave" {
  count = "${var.mesos_slave_count}"
  floating_ip = "${element(openstack_compute_floatingip_v2.floatip.*.address, count.index)}"

  name = "mesos-slave-${count.index + 1}"
	image_name = "ubuntu14.04-x64"
	flavor_name = "m1.large"
	security_groups = ["cs_tf_secgroup_1"]
	region = "RegionOne"
  key_pair = "${openstack_compute_keypair_v2.terraform.name}"

  network {
    uuid = "${openstack_networking_network_v2.network_1.id}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/chef/trusted_certs/",
      "sudo chmod 777 /etc/chef/trusted_certs"
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "file" {
    source = "zeus_informatik_uni-wuerzburg_de.crt"
    destination = "/etc/chef/trusted_certs/zeus_informatik_uni-wuerzburg_de.crt"

    connection {
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "chef" {
    node_name = "mesos-slave-${count.index + 1}"
    run_list = ["role[ls3-mesos-slave]", "recipe[host-mesos-slave]"]

    environment = "_default"
    connection {
      type = "ssh"
      user = "ubuntu"
    }
    server_url = "https://zeus.informatik.uni-wuerzburg.de/organizations/ls3"
    validation_client_name = "ls3-validator"
    validation_key = "${file("ls3-validator.pem")}"
    version = "12.5.1"
    ohai_hints = ["openstack.json"]
    ssl_verify_mode = ":verify_none"
  }
}

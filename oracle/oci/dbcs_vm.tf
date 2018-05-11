// Terraform template for Oracle Cloud Infrastructure Database Cloud Service VM

provider "oci" {
  tenancy_ocid     = "${var.tenancy_ocid}"
  user_ocid        = "${var.user_ocid}"
  fingerprint      = "${var.fingerprint}"
  private_key_path = "${var.private_key_path}"
  region           = "${var.region}"
}

data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}

resource "oci_core_virtual_network" "VCN-SB" {
  cidr_block     = "10.0.0.0/24"
  compartment_id = "${var.compartment_ocid}"
  display_name   = "VCN-SB-${var.sbName}"
  dns_label      = "sb"
}

resource "oci_core_internet_gateway" "IG-SB" {
  compartment_id = "${var.compartment_ocid}"
  display_name = "IG-SB-${var.sbName}"
  vcn_id = "${oci_core_virtual_network.VCN-SB.id}"
}

resource "oci_core_default_security_list" "default_security_list" {
  manage_default_resource_id = "${oci_core_virtual_network.VCN-SB.default_security_list_id}"
  display_name="Default Security List for VCN-SB-${var.sbName}"
  
  // allow outbound tcp traffic on all ports
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol = "6"
    stateless = "false"
  }

  // allow inbound ssh traffic
  ingress_security_rules {
    protocol = 6 // tcp
    source = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 22
      max = 22
    }
  }

  // allow inbound icmp traffic of a specific type
  ingress_security_rules {
    protocol  = 1
    source    = "0.0.0.0/0"
    stateless = false
    icmp_options {
      type = 3
      code = 4
    }
  }

  // allow inbound icmp traffic from VCN of a specific type
  ingress_security_rules {
    protocol  = 1
    source    = "10.0.0.0/24"
    stateless = false
    icmp_options {
      type = 3
    }
  }

  // allow inbound VNC traffic
  ingress_security_rules {
    protocol = "6" // tcp
    source = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 5901
      max = 5901
    }
  }
}

resource "oci_core_default_route_table" "default_route_table" {
  manage_default_resource_id = "${oci_core_virtual_network.VCN-SB.default_route_table_id}"
  display_name = "Default Route Table for VCN-SB-${var.sbName}"
  route_rules {
    cidr_block = "0.0.0.0/0"
    network_entity_id = "${oci_core_internet_gateway.IG-SB.id}"
  }
}

resource "oci_core_subnet" "SN-SB-Data" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.datastore_availability_domain],"name")}"
  cidr_block = "10.0.0.0/24"
  display_name = "SN-SB-Data"
  dns_label = "data"
  compartment_id = "${var.compartment_ocid}"
  vcn_id = "${oci_core_virtual_network.VCN-SB.id}"
  security_list_ids = ["${oci_core_virtual_network.VCN-SB.default_security_list_id}"]
  route_table_id = "${oci_core_default_route_table.default_route_table.id}"
  dhcp_options_id = "${oci_core_virtual_network.VCN-SB.default_dhcp_options_id}"
}

resource "oci_database_db_system" "SB-DataStore" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.datastore_availability_domain],"name")}"
  compartment_id = "${var.compartment_ocid}"
  cpu_core_count = "${var.data_store["CPUCoreCount"]}"
  database_edition = "${var.data_store["Edition"]}"
  db_home {
    database {
      "admin_password" = "${var.data_store["AdminPassword"]}"
      "db_name" = "${var.data_store["ContainerName"]}"
      "character_set" = "${var.data_store["CharacterSet"]}"
      "ncharacter_set" = "${var.data_store["NCharacterSet"]}"
      "db_workload" = "${var.data_store["Workload"]}"
      "pdb_name" = "${var.data_store["PDBName"]}"
    }
    db_version = "${var.data_store["Version"]}"
    display_name = "${var.data_store["DisplayName"]}"
  }
  disk_redundancy = "${var.data_store["DiskRedundancy"]}"
  shape = "${var.data_store["NodeShape"]}"
  subnet_id = "${oci_core_subnet.SN-SB-Data.id}"
  ssh_public_keys = ["${var.ssh_public_key}"]
  display_name = "${var.data_store["NodeDisplayName"]}${var.sbName}"
  domain = "${var.data_store["NodeDomainName"]}"
  hostname = "${var.data_store["NodeHostName"]}"
  data_storage_percentage = "${var.data_store["StoragePercent"]}"
  data_storage_size_in_gb = "${var.data_store["StorageSizeInGB"]}"
  license_model = "${var.data_store["LicenseModel"]}"
  node_count = "${var.data_store["NodeCount"]}"
}

# Get DB node list
data "oci_database_db_nodes" "DBNodeList" {
  compartment_id = "${var.compartment_ocid}"
  db_system_id = "${oci_database_db_system.SB-DataStore.id}"
}

# Get DB node details
data "oci_database_db_node" "DBNodeDetails" {
  db_node_id = "${lookup(data.oci_database_db_nodes.DBNodeList.db_nodes[0], "id")}"
}

# Gets the OCID of the first (default) vNIC
data "oci_core_vnic" "DBNodeVnic" {
  vnic_id = "${data.oci_database_db_node.DBNodeDetails.vnic_id}"
}

# Output the private IP of the instance
output "DBNodePublicIP" {
  value = ["${data.oci_core_vnic.DBNodeVnic.public_ip_address}"]
}

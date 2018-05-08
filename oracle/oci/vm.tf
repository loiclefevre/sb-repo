// Terraform template for Oracle Cloud Infrastructure VM

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

variable "ImageOCID" {
    type = "map"
    default = {
        // See https://docs.us-phoenix-1.oraclecloud.com/Content/Resources/Assets/OracleProvidedImageOCIDs.pdf
        // Oracle-provided image "Oracle-Linux-7.4-2018.02.21-1"
        us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaaupbfz5f5hdvejulmalhyb6goieolullgkpumorbvxlwkaowglslq"
        us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaajlw3xfie2t5t52uegyhiq2npx7bqyu4uvi2zyu3w3mqayc2bxmaa"
        eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt1.aaaaaaaa7d3fsb6272srnftyi4dphdgfjf6gurxqhmv6ileds7ba3m2gltxq"
        uk-london-1 = "ocid1.image.oc1.uk-london1.aaaaaaaaa6h6gj6v4n56mqrbgnosskq63blyv2752g36zerymy63cfkojiiq"
    }
}

resource "oci_core_instance" "SB-Client" {
    availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.client_availability_domain],"name")}" 
    compartment_id = "${var.compartment_ocid}"
    display_name = "SB-CLIENT-${var.sbName}"
    hostname_label = "client"
    source_details {
        source_type = "image"
        source_id = "${var.ImageOCID[var.region]}"
    }    
    shape = "VM.Standard1.2"
    subnet_id = "${oci_core_subnet.SN-SB-Data.id}"
    metadata {
		  ssh_authorized_keys = "${var.ssh_public_key}"
		  user_data = "${base64encode(file(var.oci_custom_bootstrap_file_name))}"
	}
}

# Output the private and public IPs of the instance
output "SB-Client-PrivateIPs" {
  value = ["${oci_core_instance.SB-Client.*.private_ip}"]
}

output "SB-Client-PublicIPs" {
  value = ["${oci_core_instance.SB-Client.*.public_ip}"]
}

# Output the boot volume IDs of the instance
output "SB-Client-BootVolumeIDs" {
  value = ["${oci_core_instance.SB-Client.*.boot_volume_id}"]
}

output "SB-Client-ImageIDs" {
  value = ["${oci_core_instance.SB-Client.source_details.source_id}"]
}

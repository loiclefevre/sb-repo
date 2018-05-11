// Terraform template for Oracle Cloud Infrastructure VM

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
  value = ["${oci_core_instance.SB-Client.source_details}"]
}

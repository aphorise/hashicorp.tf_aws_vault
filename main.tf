resource "aws_iam_user" "vault_training" {
  count = var.workstations

  name = "${var.namespace}-${element(var.ns_examples, count.index)}"
  path = "/${var.namespace}/"
}

resource "aws_iam_access_key" "vault_training" {
  count = var.workstations
  user  = element(aws_iam_user.vault_training.*.name, count.index)
}

data "template_file" "iam_policy" {
  count    = var.workstations
  template = file("${path.module}/templates/policies/iam_policy.json.tpl")

  vars = {
    identity          = element(aws_iam_user.vault_training.*.name, count.index)
    region            = var.region
    owner_id          = aws_security_group.vault_training.owner_id
    ami_id            = data.aws_ami.ubuntu.id
    subnet_id         = element(aws_subnet.vault_training.*.id, count.index)
    security_group_id = aws_security_group.vault_training.id
  }
}

# Create a limited policy for this user - this policy grants permission for the
# user to do incredibly limited things in the environment, such as launching a
# specific instance provided it has their authorization tag, deleting instances
# they have created, and describing instance data.
resource "aws_iam_user_policy" "vault_training" {
  count  = var.workstations
  name   = "policy-${element(aws_iam_user.vault_training.*.name, count.index)}"
  user   = element(aws_iam_user.vault_training.*.name, count.index)
  policy = element(data.template_file.iam_policy.*.rendered, count.index)
}

resource "random_string" "wetty" {
  length  = 16
  special = true
}

data "template_file" "workstation" {
  count = var.workstations

  template = join(
    "\n",
    [
      file("${path.module}/test.sh"),
    ],
  )

  vars = {
    namespace = var.namespace
    node_name = element(aws_iam_user.vault_training.*.name, count.index)
    me_ca     = tls_self_signed_cert.root.cert_pem
    me_cert   = element(tls_locally_signed_cert.workstation.*.cert_pem, count.index)
    me_key    = element(tls_private_key.workstation.*.private_key_pem, count.index)
    # User
    vault_training_username = var.vault_training_username
    vault_training_password = var.vault_training_password
    identity          = element(aws_iam_user.vault_training.*.name, count.index)
    # Consul
#    consul_url            = var.consul_url
#    consul_gossip_key     = base64encode(random_id.consul_gossip_key.hex)
#    consul_join_tag_key   = "ConsulJoin"
#    consul_join_tag_value = local.consul_join_tag_value
    # Terraform
    terraform_url     = var.terraform_url
    region            = var.region
    ami_id            = data.aws_ami.ubuntu.id
    subnet_id         = element(aws_subnet.vault_training.*.id, count.index)
    security_group_id = aws_security_group.vault_training.id
    access_key        = element(aws_iam_access_key.vault_training.*.id, count.index)
    secret_key        = element(aws_iam_access_key.vault_training.*.secret, count.index)
    # Tools
    consul_template_url   = var.consul_template_url
    envconsul_url         = var.envconsul_url
    packer_url            = var.packer_url
    sentinel_url          = var.sentinel_url
    dashboard_service_url = var.dashboard_service_url
    counting_service_url  = var.counting_service_url
    # Vault
    vault_url = var.vault_url
    license = var.license
    #Wetty
    wetty_pw = random_string.wetty.result
  }
}

# Gzip cloud-init config
data "template_cloudinit_config" "workstation" {
  count = var.workstations

  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = element(data.template_file.workstation.*.rendered, count.index)
  }
}

# IAM
resource "aws_iam_role" "workstation" {
  count              = var.workstations
  name               = "${element(aws_iam_user.vault_training.*.name, count.index)}-workstation"
  assume_role_policy = file("${path.module}/templates/policies/assume-role.json")
}

resource "aws_iam_policy" "workstation" {
  count       = var.workstations
  name        = "${element(aws_iam_user.vault_training.*.name, count.index)}-workstation"
  description = "Allows student ${element(aws_iam_user.vault_training.*.name, count.index)} to use their workstation."
  policy      = element(data.template_file.iam_policy.*.rendered, count.index)
}

resource "aws_iam_policy_attachment" "workstation" {
  count      = var.workstations
  name       = "${element(aws_iam_user.vault_training.*.name, count.index)}-workstation"
  roles      = [element(aws_iam_role.workstation.*.name, count.index)]
  policy_arn = element(aws_iam_policy.workstation.*.arn, count.index)
}

resource "aws_iam_instance_profile" "workstation" {
  count = var.workstations
  name  = "${element(aws_iam_user.vault_training.*.name, count.index)}-workstation"
  role  = element(aws_iam_role.workstation.*.name, count.index)
}

resource "aws_instance" "workstation" {
  count = var.workstations

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.ec2_type
  key_name      = aws_key_pair.vault_training.id

  subnet_id              = element(aws_subnet.vault_training.*.id, count.index)
  iam_instance_profile   = element(aws_iam_instance_profile.workstation.*.name, count.index)
  vpc_security_group_ids = [aws_security_group.vault_training.id]

  tags = {
    Name       = element(aws_iam_user.vault_training.*.name, count.index)
    owner      = var.owner
    created-by = var.created-by
  }

  user_data = element(
    data.template_cloudinit_config.workstation.*.rendered,
    count.index,
  )
}



provider "aws" {
  region  = var.region
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "vault_training" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true

  tags = {
    Name           = var.namespace
    owner          = var.owner
    created-by     = var.created-by
    sleep-at-night = var.sleep-at-night
    TTL            = var.TTL
  }
}

resource "aws_internet_gateway" "vault_training" {
  vpc_id = aws_vpc.vault_training.id

  tags = {
    Name           = var.namespace
    owner          = var.owner
    created-by     = var.created-by
    sleep-at-night = var.sleep-at-night
    TTL            = var.TTL
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.vault_training.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vault_training.id
}

data "aws_availability_zones" "available" {
}

resource "aws_subnet" "vault_training" {
  count                   = length(var.cidr_blocks)
  vpc_id                  = aws_vpc.vault_training.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = var.cidr_blocks[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name           = var.namespace
    owner          = var.owner
    created-by     = var.created-by
    sleep-at-night = var.sleep-at-night
    TTL            = var.TTL
  }
}

resource "aws_security_group" "vault_training" {
  name_prefix = var.namespace
  vpc_id      = aws_vpc.vault_training.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "vault_training" {
  key_name   = var.namespace
  public_key = var.public_key
}

# resource "aws_iam_role" "consul-join" {
#   name               = "${var.namespace}-consul-join"
#   assume_role_policy = file("${path.module}/templates/policies/assume-role.json")
# }
# 
# resource "aws_iam_policy" "consul-join" {
#   name        = "${var.namespace}-consul-join"
#   description = "Allows Consul nodes to describe instances for joining."
#   policy      = file("${path.module}/templates/policies/describe-instances.json")
# }
# 
# resource "aws_iam_policy_attachment" "consul-join" {
#   name       = "${var.namespace}-consul-join"
#   roles      = [aws_iam_role.consul-join.name]
#   policy_arn = aws_iam_policy.consul-join.arn
# }
# 
# resource "aws_iam_instance_profile" "consul-join" {
#   name = "${var.namespace}-consul-join"
#   role = aws_iam_role.consul-join.name
# }






# Root private key
resource "tls_private_key" "root" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

# Root certificate
resource "tls_self_signed_cert" "root" {
  key_algorithm   = tls_private_key.root.algorithm
  private_key_pem = tls_private_key.root.private_key_pem

  subject {
    common_name  = "service.vault"
    organization = "HashiCorp Training"
  }

  validity_period_hours = 720 # 30 days

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]

  is_ca_certificate = true
}

# Server private key
resource "tls_private_key" "server" {
  count       = var.servers
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

# Server signing request
resource "tls_cert_request" "server" {
  count           = var.servers
  key_algorithm   = element(tls_private_key.server.*.algorithm, count.index)
  private_key_pem = element(tls_private_key.server.*.private_key_pem, count.index)

  subject {
    common_name  = "${var.namespace}-server-${count.index}.node.vault"
    organization = "HashiCorp Training"
  }

  dns_names = [
#    "${var.namespace}-server-${count.index}.node.consul", "consul.service.consul", "server.dc1.consul", "nomad.service.consul", "client.global.nomad",
#    "server.global.nomad", "${var.namespace}-server-${count.index}.node.consul", "vault.service.consul", "active.vault.service.consul", "standby.vault.service.consul",
    "localhost",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]
}

# Server certificate
resource "tls_locally_signed_cert" "server" {
  count              = var.servers
  cert_request_pem   = element(tls_cert_request.server.*.cert_request_pem, count.index)
  ca_key_algorithm   = tls_private_key.root.algorithm
  ca_private_key_pem = tls_private_key.root.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root.cert_pem

  validity_period_hours = 720 # 30 days

  allowed_uses = [
    "client_auth",
    "digital_signature",
    "key_agreement",
    "key_encipherment",
    "server_auth",
  ]
}

# Vault initial root token
resource "random_id" "vault-root-token" {
  byte_length = 8
  prefix      = "${var.namespace}-"
}

# Client private key
resource "tls_private_key" "workstation" {
  count       = var.workstations
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

# Client signing request
resource "tls_cert_request" "workstation" {
  count           = var.workstations
  key_algorithm   = element(tls_private_key.workstation.*.algorithm, count.index)
  private_key_pem = element(tls_private_key.workstation.*.private_key_pem, count.index)

  subject {
    common_name  = "${element(aws_iam_user.vault_training.*.name, count.index)}.node.vault"
    organization = "HashiCorp Vault Testing"
  }

  dns_names = [
#    "nomad.service.consul",    "client.global.nomad",
    "${element(aws_iam_user.vault_training.*.name, count.index)}.node.vault",
    "localhost",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]
}

# Client certificate
resource "tls_locally_signed_cert" "workstation" {
  count              = var.workstations
  cert_request_pem   = element(tls_cert_request.workstation.*.cert_request_pem, count.index)
  ca_key_algorithm   = tls_private_key.root.algorithm
  ca_private_key_pem = tls_private_key.root.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root.cert_pem

  validity_period_hours = 7200 # 300 days

  allowed_uses = [
    "client_auth",
    "digital_signature",
    "key_agreement",
    "key_encipherment",
    "server_auth",
  ]
}



resource "aws_alb" "vault-training-stack" {
  name = "${var.namespace}-vault-training-stack"

  security_groups = [aws_security_group.vault_training.id]
  subnets         = aws_subnet.vault_training.*.id

  tags = {
    Name           = "${var.namespace}-vault-training-stack"
    owner          = var.owner
    created-by     = var.created-by
    sleep-at-night = var.sleep-at-night
    TTL            = var.TTL
  }
}







output "workstations" {
  value = [aws_instance.workstation.*.public_ip]
}

output "workstation_webterminal_links" {
  value = formatlist(
    "https://%s:3000/wetty/ssh/%s",
    aws_instance.workstation.*.public_ip,
    var.vault_training_username,
  )
}

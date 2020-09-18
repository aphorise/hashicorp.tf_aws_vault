#----------------------------------------------------------------------------------
# NOTE: Cloud credentials should be set in environment variables.
#       https://www.terraform.io/docs/providers/aws/index.html#environment-variables
#----------------------------------------------------------------------------------
# These variables should be set, at minimum. See `variables.tf` for others.

owner = "aphorise"
region = "eu-west-2"
workstations = "1"
namespace = "...SET... - EG: YOUR_NAME"
public_key = "ssh-rsa AAAA    ......SET......   user@host.local"

#----------------------------------------------------------------------------------
# Vault Enterprise License (for later use)
#----------------------------------------------------------------------------------
license = "..."

vault_training_username = "aphorise"
vault_training_password = "p455w0rd"

#--------------------------------------------------------------------------
# To specify the EC2 instance type (default is t2.xlarge)
#--------------------------------------------------------------------------
# ec2_type = "t2.xlarge"

## How do deploy?

### Requirements
- Terraform installed: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
- Credentials to an AWS account. See "Authenticatin to AWS API"

### Authenticating to AWS API
https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration

### Running terraform
To provision run:
```sh
cd ./Technical_Universtity_Of_Lodz_25.01.2024_AWS_Lambda/deploy
terraform init
terraform apply -auto-approve
```

After you're finished make sure to deprovision using:
```sh
terraform destroy -auto-approve
```

Terraform documentation: https://developer.hashicorp.com/terraform/docs

### API url
The API url will be given as an output after a successful 'terraform apply'

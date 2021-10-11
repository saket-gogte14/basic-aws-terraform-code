#### IAM Access and Secret Key for your IAM user
aws_access_key = 

aws_secret_key = 

# Name of the key pair in AWS, MUST be in same region as EC2 instance
# Check README for AWS CLI commands to create a key pair
key_name = "my-keys"

# Local path to pem file for key pair. 
# Windows paths need to use double-backslash: Ex. C:\\Users\\saket\\Desktop\\AWSLearning\\my-keys.pem
private_key_path = "" 

network-address-space= "10.1.0.0/16"

number_of_hosts_elb = 2

subnet-address-space= ["10.1.0.0/24","10.1.1.0/24"]
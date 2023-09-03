# devops-task

As a solution for the provided task, we have a Terraform configuration that will create a MySQL database via Aurora serverless.
For this purpose, I'm using AWS RDS Aurora Terraform module
The main.tf file contains additional configuration about the EC2 instance that we are going to use to host our application. Since the application is PHP,
we have a script that installs PHP and nginx as web server.

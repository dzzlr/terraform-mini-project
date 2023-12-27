# Terraform Mini-Project

## Overview
This repository contains Terraform scripts for a mini-project aimed at provisioning infrastructure on a cloud platform AWS. It's designed to create, manage, and update the cloud infrastructure using Terraform's declarative configuration files.

## Case Study
Our product requirement wants to have an architecture that divides the workload environment between Development and Testing.
In the Development environment there are 2 EC2 instances (1 located in the public subnet and the other in the private subnet). Meanwhile, in the Testing environment, there is only 1 EC2 instance in the private subnet.

## Contents
The project consists of the following elements:
- `main.tf`: Contains the main Terraform configuration.
- `outputs.tf`: Specifies the output configurations.
- `README.md`: Provides an overview of the project.

## Prerequisites
Before running these Terraform scripts, ensure that you have:
- Installed Terraform on your machine.
- Installed AWS CLI on your machine
- Configured the necessary cloud provider access credentials.

## Usage
1. Clone this repository to your local machine.
2. Run `aws configure` to confirm your identity and retrieve associated permissions policies in AWS.
3. Run `terraform init` to initialize the working directory.
4. Run `terraform plan` to see the execution plan.
5. Run `terraform apply` to apply the changes and provision the infrastructure.

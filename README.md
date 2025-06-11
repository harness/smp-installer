# harness-smp-installer
Installer for Harness SMP

# Supported Platforms
- AWS: Supports EKS with ALB

# Supported Profiles

| Profile | Resources          | Description                                     |
| ------- | ------------------ | ----------------------------------------------- |
| small   | 5 t2.2xlarge nodes | Supports 50 users with 10 concurrent executions |
| pov     | 2 t2.2xlarge nodes | Supports 5 users with 1 execution at a time     |

# Supported Features

| Feature            | Description                                         | Supported Platform |
| ------------------ | --------------------------------------------------- | ------------------ |
| loadbalancer       | Creates loadbalancer                                | AWS (ALB)          |
| kubernetes cluster | Creates kubernetes cluster with desired node config | AWS (EKS)          |
| vpc                | Creates VPC                                         | AWS                |
| airgap             | Creates egress rules to block outgoing traffic      | AWS                |
| tls                | Create self signed certificate                      | AWS                |
| helm chart         | Install harness helm chart with existing overrides  | AWS                |
| dns                | Create hosted zone for existing domain              | AWS (Route53)      |
| monitoring         | Install prometheus and grafana helm charts          | AWS (EKS)          |

# Quick Start

## Pre-requisites
1. Make sure you have `tofu` installed. You can check (official documentation)[https://opentofu.org/docs/intro/install/] on how to install opentofu.
2. Ensure jq is installed and is in path.

## Run
1. Clone this repository
2. Run the binary with the following command
  ```
  go build -o smp-installer github.com/harness/smp-installer/cmd
  ```
  Note: Any changes to .tf files should follow with build of above binary.
3. Use the example.yaml as your configuration reference for the tool
   - Update the necessary fields as required
5. Authenticate with AWS
   - Go to AWS IAM Console
   - Copy the access key and secret key of the user which has admin access to the AWS project
   - Export the keys in your terminal 
6. Run the sync command
  `./smp-installer sync -c ./example.yaml`
7. The tool will generate the output directory configured in `example.yaml` which will store all rendered tofu files.

# Contribute

## File structure
```
├── LICENSE
├── README.md
├── cmd                                             : contains the entrypoint for the installer
│   ├── main.go                                     : chains the individual commands
│   └── resources                                   : contains individual resource command
│       ├── harness.go
│       ├── kubernetes.go
│       ├── loadbalancer.go
│       └── resource.go
├── example.yaml                                    : sample file to test the installer
├── pkg                                             : contains internal logic
│   ├── client                                      : contains individual resource client. Each client manages the resource creation
│   │   ├── client.go
│   │   ├── helm.go
│   │   ├── kubernetes.go
│   │   └── loadbalancer.go
│   ├── render                                      : Contains template logic
│   │   └── template.go
│   ├── store                                       : Contains data store to store config and runtime output from clients
│   │   ├── memory.go
│   │   ├── memory_test.go
│   │   └── store.go
│   └── tofu                                        : Contains tofu files for all supported clouds
│       ├── aws
│       │   ├── harness                             : Harness helm chart tofu module
│       │   │   ├── harness.tf
│       │   │   ├── tf.vars
│       │   │   └── variables.tf
│       │   ├── kubernetes                          : Kubernetes cluster tofu module
│       │   │   ├── kubernetes.tf
│       │   │   ├── tf.vars
│       │   │   ├── variables.tf
│       │   │   └── vpc.tf
│       │   └── loadbalancer                        : Load balancer tofu module
│       │       ├── loadbalancer.tf
│       │       ├── tf.vars
│       │       └── variables.tf
│       ├── files.go                                : Utility to load above files
│       └── helper.go                               : Tofu helper methods
├── profiles                                        : Contains supported profile overrides
│   ├── files.go
│   └── small
│       └── override.yaml
│       └── config.yaml
│   └── pov
│       └── override.yaml
│       └── config.yaml
```

## Adding new resource
Adding a new resource requires changes atleast in 3 below places
- cmd/resources/<newresource>.go
- pkg/client/<newresource>.go
- pkg/tofu/aws/<newresource>/*

### Adding resource command
Adding a new resource command requires a new file at `cmd/resources/<newresource>.go`.

The new command type must implement the `Resource` interface and implement the below two methods.
- `Name()`: This method returns the name of the resource
- `Sync()`: This method orchestrates the resource lifecylce using resource client

### Adding resource client
Adding a new resource client requires a new file at `pkg/client/<newresource>.go`

The new client must implement the `Client` interface and implement the below methods.
- `PreExec()`: This method is invoked to prepare the environment before invoking `tofu`. This can be used to change values in some file, add data for `.Self` object to be used for rendering etc.
- `Exec()`: This method is called to invoke the tofu command. Client can use this method to check for existing tofu state, invoke tofu command, or run some other operations.
- `PostExec()`: This method is called to do cleanups. This method is expected to return the output for this resource which is used to populate the `.Output` object

### Adding tofu module
Adding a new tofu module requires adding the module at `pkg/tofu/<cloud>/<newresource>`. The tofu module must have tofu files and a var file named `tf.vars` which is either templatized or hardcoded.

## Templates
All tofu files and profile overrides can be templated. 

Installer provides below built-in objects to be used in the templates.

1. `.Config`: This object can be used to refer to values coming from installer's config file such as example.yaml.
            
            Example: {{ .Config.kubernetes.version }}
2. `.Ouput`: This object can be used to refer to output exposed by any resource client. For example, profile override can refer to loadbalancer IP like `.Output.loadbalancer.ip` if loadbalancer client exposes the output.
3. `.Self`: This object can be used to refer to data exposed by a client during its `PreExec` hook.

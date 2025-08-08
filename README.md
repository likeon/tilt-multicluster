# Tilt Multicluster

Scripts for running multiple isolated development environments in parallel
using [tilt](https://tilt.dev/) and [kind](https://kind.sigs.k8s.io/).

You don't need to run everything or anything in Kubernetes - workloads can run as local resources and still get benefits of dynamic port allocations, data duplication and nice Tilt UI.

## What it does
- Creates isolated Kind clusters with unique names
- Spins up local container registry for each cluster
- Dynamically allocates ports to avoid conflicts
- Optionally provides owned data copy for an environment
- Handles cleanup

## Example
See [geometa repository](https://github.com/likeon/geometa) for a working example. Check the `.tilt` folder for the configuration.

## Requirements
- [kind](https://kind.sigs.k8s.io/)
- [tilt](https://tilt.dev/) - Local Kubernetes development
- podman
- kubectl
- [just](https://github.com/casey/just)
  - Not a hard requirement, you can run it however you want


## Project structure
Your project needs this structure:

```
your-project/
├── Tiltfile                  # Main Tilt configuration
├── .tilt/
│   ├── project.env          # Project configuration
│   ├── k8s/                 # Kubernetes manifests (if using them)
│   │   └── *.yaml
│   └── scripts/             # this repo
│       ├── tilt-with-cluster.sh
│       ├── kind-with-registry.sh  
│       ├── find-available-port.sh
│       └── justfile
└── whatever/                    # Your application code
```

## Configuration

Create `.tilt/project.env` with:
```bash
PROJECT_NAME=your-project

# Initial ports to dynamically allocate
# Must start with TILT_PORT_ to be recognized
TILT_PORT_POSTGRES=5432
TILT_PORT_API=3000
TILT_PORT_FRONTEND=5173

# Space separated data folders that need to be precreated if you gonna mount them inside k8s
DATA_FOLDERS=postgres
```

Craft your [Tiltfile](https://docs.tilt.dev/api.html) where you use port variables set in `.tilt/project.env` - those will be swapped to available values on start.


## Running
In my projects I have root `justfile` importing tilt script `import ".tilt/scripts/justfile"`.
```bash
# normal run without data duplicate
just run

# with data duplicate
just run true
```
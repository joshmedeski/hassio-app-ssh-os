# Contributing

## Prerequisites

Install the following on your development machine (macOS):

```bash
brew install just docker sshpass mosh
```

| Tool | Purpose |
|------|---------|
| [Docker](https://www.docker.com/) | Builds and runs the add-on container |
| [just](https://github.com/casey/just) | Task runner for build, run, test, and connect commands |
| [sshpass](https://sourceforge.net/projects/sshpass/) | Passes the test password automatically to SSH/mosh |
| [mosh](https://mosh.org/) | Tests mosh connectivity to the container |

## Development workflow

The `justfile` drives all development tasks:

```bash
just build   # Build the Docker image
just run     # Build and start the container
just ssh     # Connect via SSH (password: testpassword)
just mosh    # Connect via mosh (password: testpassword)
just test    # Run the test suite
just logs    # Tail container logs
just stop    # Stop and remove the container
```

A typical cycle:

1. Make your changes
2. `just run` to rebuild and start the container
3. `just ssh` or `just mosh` to verify interactively
4. `just test` to run automated tests
5. `just stop` when done

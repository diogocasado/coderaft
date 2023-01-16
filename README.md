# :sailboat: Coderaft

Coderaft is simple tool to generate scripts that will automate setting up Linux VPS servers.

> _It's supposed to barely float your code out there. :trollface:_

## Usage

Configuring a server does not require you clone this repository.

Simple choose one of the pre-built scripts available under `./builds` and execute.

Run as root:
```
# bash < (curl -s https://raw.githubusercontent.com/diogocasado/coderaft/main/builds/platform_dist_raft.bash)
```

## Current builds

* [webnodejs](https://raw.githubusercontent.com/diogocasado/coderaft/main/builds/digitalocean_ubuntu_webnodejs.bash)
Sets up a DigitalOcean Ubuntu Linux Droplet with SSL, MongoDB and Node.js. [:hammer: Diogo Casado](https://github.com/diogocasado)

## How it works

Coderaft is just a collection of scripts that each configure a piece of software.

The build process concatenates these scripts to generate a single one-shot script.

Some of these scripts expose variables and functions that will affect the generation of configuration files.

These variables and functions can be used by other scripts to make things work together. 

The final script calls functions based on package names in the following sequence:

xxx_init (initialize vars) -> xxx_setup (interdependency config and prompts) -> xxx_install (real drill) -> xxx_finish (clean up)

Expanding to:

`Common env init`

1. platform_init
2. dist_init
3. raft_init

`Common setup`

4. platform_setup
5. dist_setup
6. raft_setup

`Setup for every package`

7. [package]_setup
8. [package]\_setup_[dist]

`Configuration prompts`

`Install for every package`

9. [package]_install
10. [package]\_install_[dist]

`Cleanup for every package`

11. [package]_finish

`Common clean up`

12. platform_finish
13. dist_finish
14. raft_finish

`Done`

## Structure

| Folder           | Description                                                |
| ---              | ---                                                        |
| `/builds`        | Pre-built scripts according to current commit              |
| `/platforms`     | Scripts for specific VPS provider platforms                |
| `/dists`         | Scripts for specific Linux distributions                   |
| `/packages`      | Scripts for installing and configuring individual software |
| `/rafts`         | Scripts specifying a Coderaft build                        |
| `/hooks`         | Git hook scripts                                           |
| `/modules`       | Optional tools that can work with Coderaft                 |
| `coderaft.bash`  | The head script that gets included in every build          |
| `build`          | The script that builds scripts                             |
| `setup`          | The script you should run when you clone the project       |

## Conventions

You can probably infer many of the conventions simply by looking at files.

In general:

- Scripts are created for bash. Thus keep .bash filename extension.
- Package script naming follows: name.bash (always included in the final script) or name-dist.bash (included only for specific dist)
- Script variables are UPPERCASE and prefixed with FILENAME_.
- Functions are lowercase and prefixed with filename_.
- Assign local parameters to variables `local VAR=$1`.
- Use comments only for obscure choices.
- Use very descriptive variable and function names.
- Do **not** use anything that does **not** come standard to VPS distributions.
- Keep it simple.
- Some barely debatable choices:
  - a [ ] over test and [[ ]]
  - curl over wget
  - awk over sed

Some loose ends:

- Document all standard global variables/functions
- Interdep functions could use a different prefix

## Modules

Dummy [https://github.com/diogocasado/coderaft-dummy]
Just a web app place holder based on node.js.

Paddle [https://github.com/diogocasado/coderaft-paddle]
A simple tool for app redeployment and monitoring based on node.js.

## Contributing

Anyone can contribute as long your code follows the above conventions.

You can open an issue and I will try to check asap. Otherwise fork and go nuts.





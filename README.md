# Typo3 Website dev setup

work in progress ...

## Environment

### Remote hoster

is where:

* the website is running
* all the content is managed (crud)

### Local dev setup

is where:

* typo3 source is managed
* extensions are installed (typo3 backend)
* is done experimenting with extensions and content
* the custom bootstrap extension is tested

## Setup

1. clone this repo including submodules
1. Create mysql db and user at remote hoster
1. copy `bin/secret-envs.sh.example` to `bin/secret-envs.sh` and change values to fit your environment
1. run `docker-compose up -d` to start local containers
1. run `bin/remote-push-typo3`
1. run setup wizard at remote hoster (https://example.com/typo3)
1. run `bin/remote-fetch`

you should now be able to access typo3 with the same configuration and content locally at http://localhost:4242/typo3 and remotely https://example.com/typo3

## Pull remote content

just run `bin/remote-fetch`

## Update typo3 remote source

run `bin/remote-push-typo3`

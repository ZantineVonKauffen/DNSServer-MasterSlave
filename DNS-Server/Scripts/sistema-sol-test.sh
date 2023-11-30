#!/bin/bash -x
#
# USAGE: ./test.sh <nameserver-ip>
#

# Salir si algún comando falla
set -euo pipefail

function resolve () {
    dig $nameserver +short $@
}

nameserver=@$1

resolve mercurio.sistema.sol
resolve venus.sistema.sol
resolve tierra.sistema.sol
resolve marte.sistema.sol

resolve ns1.sistema.sol
resolve ns2.sistema.sol

resolve sistema.sol mx
resolve sistema.sol ns

resolve -x 192.168.57.101
resolve -x 192.168.57.102
resolve -x 192.168.57.103
resolve -x 192.168.57.104

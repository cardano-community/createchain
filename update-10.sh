#!/usr/bin/env bash

set -e
# set -x

# This script will initiate the transition to protocol version 5 (Alonzo).

# You need to provide the current epoch as a positional argument (the Shelley
# update system requires this to be includded in the update proposal).


# In order for this to be successful, you need to already be in protocol version
# 4 (which happens one or two epoch boundaries after invoking update-4.sh).
# Also, you need to restart the nodes after running this script in order for the
# update to be endorsed by the nodes.

if [ ! "$1" ]; then echo "update-5.sh: expects an <N> epoch argument"; exit; fi

EPOCH=$1
export PATH=~/.local/bin:$PATH
ROOT=example
COINS_IN_INPUT=$(cardano-cli query utxo --address $(cat example/addresses/user1.addr) --testnet-magic 141 | grep lovela | head -1 | awk '{print $3}')
TXID=$(cardano-cli query utxo --address $(cat example/addresses/user1.addr) --testnet-magic 141 | grep lovela | head -1 | awk '{print $1 "#" $2 }' )
pushd ${ROOT}

#export CARDANO_NODE_SOCKET_PATH=node-bft1/node.sock


# Create the update proposal to change the protocol version to 5

rm -f update-d && cardano-cli governance create-update-proposal \
            --out-file update-d \
            --epoch ${EPOCH} \
            --genesis-verification-key-file shelley/genesis-keys/genesis1.vkey \
            --protocol-major-version 8 --protocol-minor-version 0 --cost-model-file costmdl.json --max-block-execution-units '(20000000000,62000000)'

# Create a transaction body containing the update proposal.

rm -f tx10u.txbody && cardano-cli transaction build-raw \
            --babbage-era \
            --fee 0 \
            --tx-in $TXID\
            --tx-out $(cat addresses/user1.addr)+$((${COINS_IN_INPUT} )) \
            --update-proposal-file update-d \
            --out-file tx10u.txbody

FEE=$(cardano-cli transaction calculate-min-fee --tx-body-file tx3.txbody --tx-in-count 1 --tx-out-count 1 --witness-count 2 --genesis shelley/genesis.json | awk '{print $1}')
FEE=$(( FEE + 1000000 ))

rm -f tx10u.txbody && cardano-cli transaction build-raw \
            --babbage-era \
            --fee ${FEE} \
            --tx-in $TXID\
            --tx-out $(cat addresses/user1.addr)+$(( ${COINS_IN_INPUT} - ${FEE} )) \
            --update-proposal-file update-d \
            --out-file tx10u.txbody

# Sign the transaction body with the two genesis delegate keys,
# and the the uxto spending key.

cardano-cli transaction sign \
            --signing-key-file addresses/user1.skey \
            --signing-key-file shelley/delegate-keys/delegate2.skey \
            --testnet-magic 141 \
            --tx-body-file  tx10u.txbody \
            --out-file      tx10u.tx


cardano-cli transaction submit --tx-file tx10u.tx --testnet-magic 141


#!/bin/bash

# Replace with your deployed contract address
CONTRACT_ADDRESS="0x88903c72016062BA3C45E06cF0005939718e11aE"

# Replace with your Etherscan API key if verifying on a network that requires it (e.g., mainnet, goerli)
# ETHERSCAN_API_KEY="YOUR_ETHERSCAN_API_KEY"

# Contract path and name
CONTRACT_PATH_NAME="src/BTC.B.sol:BitcoinOnAvalanche"

# RPC URL (same as in deploy.sh)
RPC_URL="https://138.68.175.242.sslip.io/ext/bc/mvVnPTEvCKjGqEvZaAXseWSiLtZ9uc3MgiQzkLzGQtBDebxGY/rpc"

# Constructor arguments (same as in deploy.sh)
CONSTRUCTOR_ARGS="0x100908A2b8C6F5e1C3a41A2f317832b0a38fFD4a 0x100908A2b8C6F5e1C3a41A2f317832b0a38fFD4a"

# Optional: Specify compiler version if auto-detection fails
# COMPILER_VERSION="0.8.20" # Example version

COMMAND="forge verify-contract \
    $CONTRACT_ADDRESS \
    $CONTRACT_PATH_NAME \
    --rpc-url $RPC_URL \
    --constructor-args "$CONSTRUCTOR_ARGS"

# Add compiler version if specified
# if [ -n "$COMPILER_VERSION" ]; then
# COMMAND="$COMMAND --compiler-version $COMPILER_VERSION"
# fi

# Add Etherscan API key if specified (and if your RPC URL points to a network Etherscan supports)
# if [ -n "$ETHERSCAN_API_KEY" ]; then
# COMMAND="$COMMAND --etherscan-api-key $ETHERSCAN_API_KEY"
# fi

echo "Running verification command:"
echo "$COMMAND"

# Execute the command
eval $COMMAND 
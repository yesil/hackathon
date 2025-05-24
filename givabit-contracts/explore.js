#!/usr/bin/env node

const RPC_URL = "https://138.68.175.242.sslip.io/ext/bc/mvVnPTEvCKjGqEvZaAXseWSiLtZ9uc3MgiQzkLzGQtBDebxGY/rpc";
const CHAIN_DECIMALS = 8; // Based on Givabit Network using BTC.b with 8 decimals

/**
 * Makes a JSON-RPC call to the configured RPC_URL.
 * @param {string} method The RPC method name.
 * @param {Array<any>} params Parameters for the RPC method.
 * @returns {Promise<any>} The result part of the JSON-RPC response.
 */
async function makeRpcCall(method, params = []) {
    const response = await fetch(RPC_URL, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            jsonrpc: '2.0',
            id: 1, // Static ID is fine for simple sequential requests
            method: method,
            params: params,
        }),
    });

    if (!response.ok) {
        const errorBody = await response.text();
        throw new Error(`HTTP error! status: ${response.status}, message: ${errorBody}`);
    }

    const jsonResponse = await response.json();

    if (jsonResponse.error) {
        throw new Error(`RPC error: ${jsonResponse.error.message} (Code: ${jsonResponse.error.code})`);
    }
    return jsonResponse.result;
}

/**
 * Converts a hexadecimal string to a decimal string.
 * @param {string} hex The hexadecimal string (e.g., "0x1a").
 * @returns {string} The decimal representation as a string.
 */
function hexToDecimalString(hex) {
    if (!hex || hex === "0x") return "0";
    return BigInt(hex).toString();
}

/**
 * Formats a raw transaction value (hex string) into a human-readable decimal string,
 * considering the chain's native currency decimals.
 * @param {string} valueHex The hexadecimal string of the value.
 * @param {number} decimals The number of decimals for the currency.
 * @returns {string} Formatted decimal string, e.g., "1.2345".
 */
function formatValue(valueHex, decimals) {
    if (!valueHex || valueHex === "0x") return "0.0";
    const rawValue = BigInt(valueHex);
    if (rawValue === 0n) return "0.0";

    const divisor = BigInt(10) ** BigInt(decimals);
    const integerPart = rawValue / divisor;
    let fractionalPartBN = rawValue % divisor;

    if (decimals === 0) return integerPart.toString();

    let fractionalString = fractionalPartBN.toString().padStart(decimals, '0');
    
    // Trim trailing zeros from fractional part for cleaner display
    let trimmedFractional = fractionalString.replace(/0+$/, '');
    
    if (trimmedFractional === '') {
        return `${integerPart}.0`; // e.g., 123.0
    } else {
        return `${integerPart}.${trimmedFractional}`; // e.g., 123.456 or 0.001
    }
}

/**
 * Fetches the latest block number from the blockchain.
 * @returns {Promise<number>} The latest block number as a decimal.
 */
async function getLatestBlockNumber() {
    const blockNumberHex = await makeRpcCall('eth_blockNumber');
    return parseInt(blockNumberHex, 16);
}

/**
 * Fetches a block by its number.
 * @param {string} blockNumberHex The block number in hexadecimal format (e.g., "0xabc").
 * @returns {Promise<object|null>} The block object with full transaction details, or null if not found.
 */
async function getBlockByNumber(blockNumberHex) {
    // The 'true' flag requests full transaction objects, not just hashes.
    return await makeRpcCall('eth_getBlockByNumber', [blockNumberHex, true]);
}

/**
 * Fetches the transaction receipt for a given transaction hash.
 * @param {string} txHash The hash of the transaction.
 * @returns {Promise<object|null>} The transaction receipt object, or null if an error occurs or not found.
 */
async function getTransactionReceipt(txHash) {
    try {
        // eth_getTransactionReceipt can return null if the transaction is not yet mined or not found
        const receipt = await makeRpcCall('eth_getTransactionReceipt', [txHash]);
        return receipt;
    } catch (e) {
        // makeRpcCall would have thrown for RPC/network errors.
        // This catch is more for unexpected issues if makeRpcCall was changed or for safety.
        console.warn(`  [Warning] Error encountered while trying to fetch receipt for ${txHash}: ${e.message.split('\n')[0]}`);
        return null;
    }
}

/**
 * Main function to fetch and display the last 3 transactions.
 */
async function main() {
    try {
        // Determine the number of transactions to fetch from command-line arguments
        let numTransactionsToFetch = 1; // Default to 1 transaction
        if (process.argv.length > 2) {
            const arg = parseInt(process.argv[2], 10);
            if (!isNaN(arg) && arg > 0) {
                numTransactionsToFetch = arg;
            }
        }

        console.log(`Connecting to RPC endpoint: ${RPC_URL}`);
        const latestBlockNum = await getLatestBlockNumber();
        console.log(`Latest block number: ${latestBlockNum}`);

        let collectedTransactions = [];
        // Scan a reasonable number of recent blocks to find transactions.
        // Adjust if the chain is very sparse or very busy.
        // We might need to scan more blocks if numTransactionsToFetch is high.
        const baseBlocksToScan = 20;
        const blocksToScan = Math.max(baseBlocksToScan, numTransactionsToFetch * 5); // Heuristic for scanning enough blocks
        let currentBlockNum = latestBlockNum;

        console.log(`Fetching up to ${numTransactionsToFetch} most recent transaction(s) (scanning last ${blocksToScan} blocks if needed)...`);

        for (let i = 0; i < blocksToScan && collectedTransactions.length < numTransactionsToFetch && currentBlockNum >= 0; i++) {
            const blockNumberHex = `0x${currentBlockNum.toString(16)}`;
            // console.log(`Scanning block ${currentBlockNum} (${blockNumberHex})...`); // Uncomment for verbose logging
            const block = await getBlockByNumber(blockNumberHex);

            if (block && block.transactions && block.transactions.length > 0) {
                // Iterate transactions in the block from last to first (most recent in block to oldest in block)
                // This ensures that when we add to collectedTransactions, we are adding more recent transactions first.
                for (let j = block.transactions.length - 1; j >= 0; j--) {
                    if (collectedTransactions.length < numTransactionsToFetch) {
                        const tx = block.transactions[j];
                        // Augment transaction object with block timestamp and consistent block number format
                        tx.blockTimestamp = block.timestamp; // Hex string (seconds)
                        tx.blockNumberDecimal = parseInt(block.number, 16); // Store decimal for easy reference
                        collectedTransactions.push(tx);
                    } else {
                        break; // We have collected enough transactions
                    }
                }
            }
            if (collectedTransactions.length >= numTransactionsToFetch) {
                break; // Stop scanning blocks if we have enough transactions
            }
            currentBlockNum--;
        }

        if (collectedTransactions.length === 0) {
            console.log(`No transactions found in the last ${blocksToScan} scanned blocks.`);
            return;
        }

        console.log(`\n--- Displaying ${collectedTransactions.length} Most Recent Transaction(s) ---`);
        
        // collectedTransactions are now ordered with the most recent at index 0
        // Use for...of loop to allow async operations like fetching receipts
        for (const [index, tx] of collectedTransactions.entries()) {
            const blockTimestamp = parseInt(tx.blockTimestamp, 16);
            const valueFormatted = formatValue(tx.value, CHAIN_DECIMALS);

            console.log(`\nTransaction #${index + 1} (Most Recent of the fetched set):`);
            console.log(`  Hash: ${tx.hash}`);
            console.log(`  Block Number: ${tx.blockNumberDecimal} (${tx.blockNumber})`);
            console.log(`  Timestamp: ${new Date(blockTimestamp * 1000).toUTCString()} (Unix: ${blockTimestamp})`);
            console.log(`  From: ${tx.from}`);

            if (tx.to) { // Standard transaction or contract call
                console.log(`  To: ${tx.to}`);
                // Check if input data suggests contract interaction (more than just "0x")
                if (tx.input && tx.input.length > 2) { 
                    console.log(`    (Note: Transaction has input data, likely a contract interaction)`);
                }
            } else { // Contract creation (tx.to is null or undefined)
                console.log(`  To: Contract Creation / Deployment`); 
                const receipt = await getTransactionReceipt(tx.hash); // await here
                if (receipt && receipt.contractAddress) {
                    console.log(`  Created Contract Address: ${receipt.contractAddress}`);
                    tx.createdContractAddress = receipt.contractAddress; // Store for balance check
                } else if (receipt) {
                    // Receipt fetched, but no contractAddress field, or it's null
                    console.log(`    (Info: Receipt found for ${tx.hash}, but no created contractAddress. Status: ${receipt.status})`);
                } else {
                    // getTransactionReceipt returned null (RPC call might have failed, warning logged by getTransactionReceipt)
                    console.log(`    (Info: Could not retrieve receipt for ${tx.hash} to find created contract address)`);
                }
            }

            console.log(`  Value: ${valueFormatted} (Raw Hex: ${tx.value})`);
            console.log(`  Gas Price: ${hexToDecimalString(tx.gasPrice)} wei`);
            console.log(`  Gas Limit: ${hexToDecimalString(tx.gas)}`);
            if (tx.input && tx.input.length > 2) { // Check for non-empty input data
                console.log(`  Input Data: ${tx.input.substring(0, 66)}${tx.input.length > 66 ? '...' : ''} (Length: ${tx.input.length - 2} hex chars)`);
            } else {
                console.log(`  Input Data: None`);
            }
            console.log(`  Transaction Index in Block: ${parseInt(tx.transactionIndex, 16)}`);
        }

        // --- Begin: Added code for wallet balances ---
        console.log(`
--- Collecting Wallet Balances ---`);
        const involvedWallets = new Set();
        for (const tx of collectedTransactions) {
            if (tx.from) involvedWallets.add(tx.from);
            if (tx.to) involvedWallets.add(tx.to);
            if (tx.createdContractAddress) involvedWallets.add(tx.createdContractAddress);
        }

        if (involvedWallets.size > 0) {
            console.log(`
--- Wallet Balances (${involvedWallets.size} unique addresses) ---`);
            for (const address of involvedWallets) {
                try {
                    const balanceHex = await makeRpcCall('eth_getBalance', [address, 'latest']);
                    const balanceFormatted = formatValue(balanceHex, CHAIN_DECIMALS);
                    console.log(`  ${address}: ${balanceFormatted}`);
                } catch (e) {
                    console.warn(`  [Warning] Could not fetch balance for ${address}: ${e.message.split('\n')[0]}`);
                }
            }
        } else {
            console.log("No wallet addresses identified to fetch balances for.");
        }
        // --- End: Added code for wallet balances ---

    } catch (error) {
        console.error("\n-----------------------------------------");
        console.error("Error fetching or processing blockchain data:");
        console.error(`Message: ${error.message}`);
        if (error.cause) {
             console.error("Cause:", error.cause);
        }
        console.error("-----------------------------------------");
    }
}

main(); 
// Import the ethers library
const ethers = require('ethers');

const seedPhrase = process.env.SEED_PHRASE;

// The standard C-Chain derivation path is m/44'/60'/0'/0/0
// For other accounts, you can increment the last number (the index)
const derivationPath = "m/44'/60'/0'/0/0";

// --- Key Generation ---
try {
    // Create a wallet instance from the mnemonic
    const wallet = ethers.Wallet.fromPhrase(seedPhrase);

    // Derive the specific account using the derivation path
    // Note: ethers.Wallet.fromPhrase directly gives the wallet for the default path (m/44'/60'/0'/0/0 usually)
    // If you need a different account from the same seed, you'd typically use HDNodeWallet
    const derivedNode = ethers.HDNodeWallet.fromPhrase(seedPhrase, null, derivationPath);

    const privateKey = derivedNode.privateKey;
    const publicKey = derivedNode.publicKey;
    const address = derivedNode.address;

    // --- Output ---
    console.log("Seed Phrase (Mnemonic):", seedPhrase); // For verification, but be careful where you log this!
    console.log("Derivation Path:", derivationPath);
    console.log("----------------------------------------------------");
    console.log("Derived Account Details:");
    console.log("  Private Key:", privateKey);
    console.log("  Public Key:", publicKey);
    console.log("  C-Chain Address:", address);
    console.log("----------------------------------------------------");
    console.log("⚠️  IMPORTANT: Secure your private key and seed phrase. Do not share them! ⚠️");

} catch (error) {
    console.error("Error generating keys:", error);
    if (error.message.includes("invalid mnemonic")) {
        console.error("Please ensure your seed phrase is correct and typically consists of 12 or 24 words separated by single spaces.");
    }
}
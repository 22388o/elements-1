Sequentia Blockchain
====================================


This is the integration and staging tree for the Sequentia blockchain platform,
a collection of feature experiments and extensions to the Bitcoin protocol.

Modes
-----

Elements supports a few different pre-set chains for syncing. Note though some are intended for QA and debugging only:

* Sequentia mode: `sequentiad -chain=sequentiav1` (syncs with Sequentia network)
* Bitcoin mainnet mode: `sequentiad -chain=main` (not intended to be run for commerce)
* Bitcoin testnet mode: `sequentiad-chain=testnet3`
* Bitcoin regtest mode: `sequentiad -chain=regtest`
* Sequentia custom chains: Any other `-chain=` argument. It has regtest-like default parameters that can be over-ridden by the user by a rich set of start-up options.

Features of the Sequentia blockchain platform
----------------

Compared to Bitcoin itself, it adds the following features:
 * Confidential Assets
 * Confidential Transactions
 * Signed Blocks
 * Additional opcodes
 * Proof of Stake

Lincense

MIT

What is the Sequentia?
-----------------
Sequentia is an open source, sidechain-capable blockchain platform. It also allows experiments to more rapidly bring technical innovation to the Bitcoin ecosystem.

Learn more on the [Sequentia website](https://sequentia.io)


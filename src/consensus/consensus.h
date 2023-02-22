// Copyright (c) 2009-2010 Satoshi Nakamoto
// Copyright (c) 2009-2018 The Bitcoin Core developers
// Copyright (c) 2022-2023 Sequentia Foundation
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#ifndef BITCOIN_CONSENSUS_CONSENSUS_H
#define BITCOIN_CONSENSUS_CONSENSUS_H
 

#include <stdlib.h>
#include <stdint.h>

/** The maximum allowed size for a serialized block, in bytes (only for buffer size limits) */
static const unsigned int MAX_BLOCK_SERIALIZED_SIZE = 4000000;
/** The maximum allowed weight for a block, see BIP 141 (network rule) */
static const unsigned int MAX_BLOCK_WEIGHT = 4000000;
/** The maximum allowed number of signature check operations in a block (network rule) */
static const int64_t MAX_BLOCK_SIGOPS_COST = 80000;
/** Coinbase transaction outputs can only be spent after this number of new blocks (network rule) */
static const int COINBASE_MATURITY = 100;

static const int WITNESS_SCALE_FACTOR = 4;

static const size_t MIN_TRANSACTION_WEIGHT = WITNESS_SCALE_FACTOR * 60; // 60 is the lower bound for the size of a valid serialized CTransaction
static const size_t MIN_SERIALIZABLE_TRANSACTION_WEIGHT = WITNESS_SCALE_FACTOR * 10; // 10 is the lower bound for the size of a serialized CTransaction

/** Flags for nSequence and nLockTime locks */
/** Interpret sequence numbers as relative lock-time constraints. */
static constexpr unsigned int LOCKTIME_VERIFY_SEQUENCE = (1 << 0);
/** Use GetMedianTimePast() instead of nTime for end point timestamp. */
static constexpr unsigned int LOCKTIME_MEDIAN_TIME_PAST = (1 << 1);

/** Flags for nSequence and nRevalitveTime locks */
static constexpr unsigned int RELATIVETIME_VERIFY_SEQUENCE = (1 << 0);
static constexpr unsigned int RELATIVETIME_MEDIAN_TIME_PAST = (1 << 0);

#endif // BITCOIN_CONSENSUS_CONSENSUS_H

#ifndef  PROOF_OF_STAKE_CONSENSUS_H 
#define  PROOF_OF_STAKE_CONSENSUS_H

#include <stdlib.h>
#include <stdint.h>

/** The maximum allowed size for a serialized block, in bytes (only for buffer size limits) */
static const unsigned int MAX_BLOCK_SERIALIZED_SIZE = 6000000;
/** The maximum allowed weight for a block, see BIP 141 (network rule) */
static const unsigned int MAX_BLOCK_WEIGHT = 4000000;
/** The maximum allowed number of signature check operations in a block (network rule) */
static const int64_t MAX_BLOCK_SIGOPS_COST = 90000;
/** Coinbase transaction outputs can only be spent after this number of new blocks (network rule) */
static const int COINBASE_MATURITY = 200;

static const int WITNESS_SCALE_FACTOR = 4;

static const unsigned int GOVERNANCE_VOTE = 1
/** Each stakeholder can vote only once with SEQ tokens*/

static const unsigned int VALIDATION_BLOCK = 6
/** There's each 6 blocks have validation like have on Bitcoin protocol. Like this PoW/PoS works together*/

static const int GOVERNANCE_VOTE = 1
static const int VALIDATION_BLOCK = 6
   
static const size_t IN_TRANSACTION_WEIGHT = WITNESS_SCALE_FACTOR * 80; // 80 is the lower bound for the size of a valid serialized CTransaction
static const size_t MIN_SERIALIZABLE_TRANSACTION_WEIGHT = WITNESS_SCALE_FACTOR * 20; // 10 is the lower bound for the size of a serialized CTransaction    

#endif // PROOF_OF_STAKE_CONSENSUS_H



{-# LANGUAGE DeriveTraversable #-}
-- | This module defines the data structures that make up the signed data in a Bitcoin transaction.
module Simplicity.Elements.DataTypes
  ( Point(..)
  , Script
  , TxNullDatumF(..), TxNullDatum, TxNullData, txNullData
  , Lock, Value, Entropy
  , Confidential(..), prf_
  , AssetWith(..), AssetWithWitness, Asset, asset, clearAssetPrf, putAsset
  , AmountWith(..), AmountWithWitness, Amount, amount, clearAmountPrf, putAmount
  , TokenAmountWith, TokenAmountWithWitness, TokenAmount
  , Nonce(..)
  , putNonce, getNonce
  , putIssuance
  , NewIssuance(..)
  , Reissuance(..)
  , Issuance
  , Outpoint(Outpoint), opHash, opIndex
  , UTXO(UTXO), utxoAsset, utxoAmount, utxoScript
  , SigTxInput(SigTxInput), sigTxiIsPegin, sigTxiPreviousOutpoint, sigTxiTxo, sigTxiSequence, sigTxiIssuance
  , sigTxiIssuanceEntropy, sigTxiIssuanceAsset, sigTxiIssuanceToken
  , TxOutput(TxOutput), txoAsset, txoAmount, txoNonce, txoScript
  , SigTx(SigTx), sigTxVersion, sigTxIn, sigTxOut, sigTxLock, sigTxInputsHash, sigTxOutputsHash
  , TapEnv(..)
  , txIsFinal, txLockDistance, txLockDuration
  , calculateIssuanceEntropy, calculateAsset, calculateToken
  , module Simplicity.Bitcoin
  ) where

import Control.Monad (guard, mzero)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BSL
import Data.Semigroup (Max(Max,getMax))
import Data.Word (Word64, Word32, Word16, Word8)
import Data.Serialize ( Serialize, encode
                      , Get, get, runGetLazy, lookAhead, getWord8, getWord16le, getWord32le, getLazyByteString, isEmpty
                      , Putter, put, putWord8, putWord32le, putWord64be, putLazyByteString, runPutLazy
                      )
import Data.Vector (Vector)
import Lens.Family2 ((&), (.~), (^.), over, review, under)
import Lens.Family2.Unchecked (Adapter, adapter, Traversal)

import Simplicity.Bitcoin
import Simplicity.Digest
import Simplicity.LibSecp256k1.Spec
import Simplicity.LibSecp256k1.Schnorr
import Simplicity.Word

-- | Unparsed Bitcoin Script.
-- Script in transactions outputs do not have to be parsable, so we encode this as a raw 'Data.ByteString.ByteString'.
type Script = BSL.ByteString
type SurjectionProof = BSL.ByteString
type RangeProof = BSL.ByteString

data TxNullDatumF a = Immediate a
                    | PushData a
                    | PushData2 a
                    | PushData4 a
                    | OP1Negate
                    | OPReserved
                    | OP1
                    | OP2
                    | OP3
                    | OP4
                    | OP5
                    | OP6
                    | OP7
                    | OP8
                    | OP9
                    | OP10
                    | OP11
                    | OP12
                    | OP13
                    | OP14
                    | OP15
                    | OP16
                    deriving (Functor, Foldable, Traversable, Show)

type TxNullDatum = TxNullDatumF BSL.ByteString
type TxNullData = [TxNullDatum]

getTxNullDatum :: Get TxNullDatum
getTxNullDatum = getWord8 >>= go
 where
  go 0x60 = return OP16
  go 0x5f = return OP15
  go 0x5e = return OP14
  go 0x5d = return OP13
  go 0x5c = return OP12
  go 0x5b = return OP11
  go 0x5a = return OP10
  go 0x59 = return OP9
  go 0x58 = return OP8
  go 0x57 = return OP7
  go 0x56 = return OP6
  go 0x55 = return OP5
  go 0x54 = return OP4
  go 0x53 = return OP3
  go 0x52 = return OP2
  go 0x51 = return OP1
  go 0x50 = return OPReserved
  go 0x4f = return OP1Negate
  go 0x4e = do
    n <- getWord32le
    PushData4 <$> getLazyByteString (fromIntegral n)
  go 0x4d = do
    n <- getWord16le
    PushData2 <$> getLazyByteString (fromIntegral n)
  go 0x4c = do
    n <- getWord8
    PushData <$> getLazyByteString (fromIntegral n)
  go op | op < 0x4c = Immediate <$> getLazyByteString (fromIntegral op)
        | otherwise = fail $ "Serialize.get{getTxNullDatum}: " ++ show op ++ "is not a push-data opcode."

txNullData :: Script -> Maybe TxNullData
txNullData = either (const Nothing) Just . runGetLazy prog
 where
  prog = do
    0x6a <- getWord8
    go
  go = do
    emp <- isEmpty
    if emp then return [] else ((:) <$> getTxNullDatum <*> go)

getFE :: Get FE
getFE = fmap fe_unpack get >>= maybe mzero return

putFE :: Putter FE
putFE = put . fe_pack

-- | Transaction locktime.
-- This represents either a block height or a block time.
-- It is encoded as a 32-bit value.
type Lock = Word32

type Value = Word64

type Entropy = Hash256

data Confidential prf a = Explicit a
                        | Confidential Point prf
                        deriving Show

prf_ :: Traversal (Confidential prfA a) (Confidential prfB a) prfA prfB
prf_ f (Confidential pt prf) = Confidential pt <$> f prf
prf_ f (Explicit x) = pure (Explicit x)

newtype AssetWith prf = Asset (Confidential prf Hash256) deriving Show
type Asset = AssetWith ()
type AssetWithWitness = AssetWith SurjectionProof

asset :: Adapter (AssetWith prfA) (AssetWith prfB) (Confidential prfA Hash256) (Confidential prfB Hash256)
asset = adapter to fro
 where
  to (Asset x) = x
  fro x = (Asset x)

clearAssetPrf :: AssetWith prf -> Asset
clearAssetPrf x = x & under asset . prf_ .~ ()

putAsset :: Putter Asset
putAsset (Asset (Explicit h)) = putWord8 0x01 >> put h
putAsset (Asset (Confidential (Point by x) _)) = putWord8 (if by then 0x0b else 0x0a) >> putFE x

newtype AmountWith prf = Amount (Confidential prf Value) deriving Show
type Amount = AmountWith ()
type AmountWithWitness = AmountWith RangeProof

type TokenAmountWith prf = AmountWith prf
type TokenAmount = Amount
type TokenAmountWithWitness = AmountWithWitness

amount :: Adapter (AmountWith prfA) (AmountWith prfB) (Confidential prfA Value) (Confidential prfB Value)
amount = adapter to fro
 where
  to (Amount x) = x
  fro x = (Amount x)

clearAmountPrf :: AmountWith prf -> Amount
clearAmountPrf x = x & under amount . prf_ .~ ()

putAmount :: Putter Amount
putAmount (Amount (Explicit v)) = putWord8 0x01 >> putWord64be v
putAmount (Amount (Confidential (Point by x) _)) = putWord8 (if by then 0x09 else 0x08) >> putFE x

newtype Nonce = Nonce { nonce :: Confidential () Hash256 } deriving Show

instance Serialize Nonce where
  put (Nonce (Explicit h)) = putWord8 0x01 >> put h
  put (Nonce (Confidential (Point by x) _)) = putWord8 (if by then 0x03 else 0x02) >> putFE x
  get = lookAhead getWord8 >>= go
   where
    go 0x01 = getWord8 *> (Nonce . Explicit <$> get)
    go 0x02 = Nonce . flip Confidential () . Point False <$> getFE
    go 0x03 = Nonce . flip Confidential () . Point True <$> getFE
    go _ = fail "Serialize.get{Simplicity.Primitive.Elements.DataTypes.Nonce}: bad prefix."

putMaybeConfidential :: Putter a -> Putter (Maybe a)
putMaybeConfidential _ Nothing = putWord8 0x00
putMaybeConfidential p (Just a) = p a

getMaybeConfidential :: Get a -> Get (Maybe a)
getMaybeConfidential g = lookAhead getWord8 >>= go
 where
  go 0x00 = getWord8 *> pure Nothing
  go _ = Just <$> g

putNonce :: Putter (Maybe Nonce)
putNonce = putMaybeConfidential put

getNonce :: Get (Maybe Nonce)
getNonce = getMaybeConfidential get

data NewIssuance = NewIssuance { newIssuanceContractHash :: Hash256
                               , newIssuanceAmount :: AmountWithWitness
                               , newIssuanceTokenAmount :: TokenAmountWithWitness
                               } deriving Show

data Reissuance = Reissuance { reissuanceBlindingNonce :: Hash256
                             , reissuanceEntropy :: Entropy
                             , reissuanceAmount :: AmountWithWitness
                             } deriving Show

type Issuance = Either NewIssuance Reissuance

putIssuance :: Putter (Maybe Issuance)
putIssuance Nothing = putWord8 0x00 >> putWord8 0x00
putIssuance (Just x) = go x
 where
  maybeZero (Amount (Explicit 0)) = Nothing
  maybeZero x = Just x
  -- We serialize the range/surjection proofs separately.
  go (Left new) = putMaybeConfidential putAmount (maybeZero . clearAmountPrf $ newIssuanceAmount new)
               >> putMaybeConfidential putAmount (maybeZero . clearAmountPrf $ newIssuanceTokenAmount new)
               >> put (0 :: Word256)
               >> put (newIssuanceContractHash new)
               >> put (bslHash (newIssuanceAmount new ^. (under amount.prf_)))
               >> put (bslHash (newIssuanceTokenAmount new ^. (under amount.prf_)))
  go (Right re) = putAmount (clearAmountPrf $ reissuanceAmount re)
               >> putWord8 0x00
               >> put (reissuanceBlindingNonce re)
               >> put (reissuanceEntropy re)
               >> put (bslHash (reissuanceAmount re ^. (under amount.prf_)))
               >> put (bslHash mempty)

-- | An outpoint is an index into the TXO set.
data Outpoint = Outpoint { opHash :: Hash256
                         , opIndex :: Word32
                         } deriving Show

instance Serialize Outpoint where
  get = Outpoint <$> get <*> getWord32le
  put (Outpoint h i) = put h >> putWord32le i

-- | The data type for unspent transaction outputs.
data UTXO = UTXO { utxoAsset :: Asset
                 , utxoAmount :: Amount
                 , utxoScript :: Script -- length must be strictly less than 2^32.
                 } deriving Show

-- | The data type for signed transaction inputs, including a copy of the TXO being spent.
-- For pegins, the TXO data in 'sigTxiTxo' is synthesized.
data SigTxInput = SigTxInput { sigTxiIsPegin :: Bool
                             , sigTxiPreviousOutpoint :: Outpoint
                             , sigTxiTxo :: UTXO
                             , sigTxiSequence :: Word32
                             , sigTxiIssuance :: Maybe Issuance
                             } deriving Show

-- | The data type for transaction outputs.
-- The signed transactin output format is identical to the serialized transaction output format.
data TxOutput = TxOutput { txoAsset :: AssetWithWitness
                         , txoAmount :: AmountWithWitness
                         , txoNonce :: Maybe Nonce
                         , txoScript :: Script -- length must be strictly less than 2^32.
                         } deriving Show

-- | The data type for transactions in the context of signatures.
-- The data signed in a BIP 143 directly covers input values.
data SigTx = SigTx { sigTxVersion :: Word32
                   , sigTxIn :: Vector SigTxInput
                   , sigTxOut :: Vector TxOutput
                   , sigTxLock :: Lock
                   } deriving Show

sigTxInputsHash tx = bslHash . runPutLazy $ mapM_ go (sigTxIn tx)
 where
  go txi = put (sigTxiPreviousOutpoint txi)
        >> putWord32le (sigTxiSequence txi)
        >> putIssuance (sigTxiIssuance txi)

sigTxOutputsHash tx = bslHash . runPutLazy $ mapM_ go (sigTxOut tx)
 where
  go txo = putAsset (clearAssetPrf $ txoAsset txo)
        >> putAmount (clearAmountPrf $ txoAmount txo)
        >> putNonce (txoNonce txo)
        >> put (bslHash (txoScript txo))
        >> put (bslHash (txoAsset txo ^. (under asset.prf_)))
        >> put (bslHash (txoAmount txo ^. (under amount.prf_)))

-- | Taproot specific environment data about the input being spent.
data TapEnv = TapEnv { tapAnnex :: Maybe BSL.ByteString
                     , tapLeafVersion :: Word8
                     , tapInternalKey :: PubKey
                     , tapBranch :: [Hash256]
                     } deriving Show

txIsFinal :: SigTx -> Bool
txIsFinal tx = all finalSequence (sigTxIn tx)
 where
  finalSequence sigin = sigTxiSequence sigin == maxBound

txLockDistance :: SigTx -> Word16
txLockDistance tx | sigTxVersion tx < 2 = 0
                  | otherwise = getMax . foldMap distance $ sigTxIn tx
 where
  distance sigin = case parseSequence (sigTxiSequence sigin) of
                     Just (Left x) -> Max x
                     _ -> mempty

txLockDuration :: SigTx -> Word16
txLockDuration tx | sigTxVersion tx < 2 = 0
                  | otherwise = getMax . foldMap duration $ sigTxIn tx
 where
  duration sigin = case parseSequence (sigTxiSequence sigin) of
                     Just (Right x) -> Max x
                     _ -> mempty

-- | An implementation of GenerateIssuanceEntropy from Element's 'issuance.cpp'.
calculateIssuanceEntropy :: Outpoint -> Hash256 -> Entropy
calculateIssuanceEntropy op contract = ivHash $ compress noTagIv (bsHash (encode (bsHash (encode op))), contract)

-- | An implementation of CalculateAsset from Element's 'issuance.cpp'.
calculateAsset :: Entropy -> Hash256
calculateAsset entropy = ivHash $ compress noTagIv (entropy, review (over le256) 0)

-- | An implementation of CalculateToken from Element's 'issuance.cpp'.
calculateToken :: AmountWith prf -> Entropy -> Hash256
calculateToken amt entropy = ivHash $ compress noTagIv (entropy, review (over le256) tag)
 where
  tag | Amount (Explicit _) <- amt = 1
      | Amount (Confidential _ _) <- amt = 2

-- | The entropy value of an issuance there is one, either given by a reissuance, or derived from a new issuance.
sigTxiIssuanceEntropy :: SigTxInput -> Maybe Entropy
sigTxiIssuanceEntropy txi = either mkEntropy reissuanceEntropy <$> sigTxiIssuance txi
 where
  mkEntropy = calculateIssuanceEntropy (sigTxiPreviousOutpoint txi) . newIssuanceContractHash

-- | The issued asset ID if there is an issuance.
sigTxiIssuanceAsset :: SigTxInput -> Maybe Hash256
sigTxiIssuanceAsset = fmap calculateAsset . sigTxiIssuanceEntropy

-- | The issued token ID if there is an issuance.
sigTxiIssuanceToken :: SigTxInput -> Maybe Hash256
sigTxiIssuanceToken txi = calculateToken <$> amount <*> entropy
 where
  amount = either newIssuanceAmount reissuanceAmount <$> sigTxiIssuance txi
  entropy = sigTxiIssuanceEntropy txi

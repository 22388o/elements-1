{-# LANGUAGE GADTs, ScopedTypeVariables #-}
-- | This module provides the Simplicity primitives specific for Elements sidechain applications.
module Simplicity.Elements.Primitive
  ( Prim(..), primPrefix, primName
  , getPrimBit, putPrimBit
  , PrimEnv, primEnv, envTx, envIx, envTap, envScriptCMR
  , primSem
  -- * Re-exported Types
  , S, Conf
  -- * Unimplemented
  , getPrimByte, putPrimByte
  ) where

import Control.Monad ((<=<), guard)
import qualified Data.ByteString.Lazy as BSL
import qualified Data.List as List
import Data.Maybe (fromMaybe, listToMaybe)
import qualified Data.Monoid as Monoid
import Data.Serialize (Get, getWord8,
                       Putter, put, putWord8, putWord32le, putWord64le, runPutLazy)
import qualified Data.Word
import Data.Vector as Vector ((!?), length)
import Lens.Family2 (to, view, under)
import Lens.Family2.Stock (some_)

import Simplicity.Digest
import Simplicity.Elements.DataTypes
import qualified Simplicity.LibSecp256k1.Schnorr as Schnorr
import qualified Simplicity.LibSecp256k1.Spec as Schnorr
import Simplicity.Programs.Elements
import Simplicity.Programs.LibSecp256k1
import Simplicity.Serialization
import Simplicity.Ty
import Simplicity.Ty.Bit
import Simplicity.Ty.Word

just_ f = some_ f

data Prim a b where
  Version :: Prim () Word32
  LockTime :: Prim () Word32
  InputsHash :: Prim () Word256
  OutputsHash :: Prim () Word256
  NumInputs :: Prim () Word32
  InputIsPegin :: Prim Word32 (S Bit)
  InputPrevOutpoint :: Prim Word32 (S (Word256,Word32))
  InputAsset :: Prim Word32 (S (Conf Word256))
  InputAmount :: Prim Word32 (S (Conf Word64))
  InputScriptHash :: Prim Word32 (S Word256)
  InputSequence :: Prim Word32 (S Word32)
  InputReissuanceBlinding :: Prim Word32 (S (S Word256))
  InputNewIssuanceContract :: Prim Word32 (S (S Word256))
  InputReissuanceEntropy :: Prim Word32 (S (S Word256))
  InputIssuanceAssetAmt :: Prim Word32 (S (S (Conf Word64)))
  InputIssuanceTokenAmt :: Prim Word32 (S (S (Conf Word64)))
  InputIssuanceAssetProof :: Prim Word32 (S Word256)
  InputIssuanceTokenProof :: Prim Word32 (S Word256)
  CurrentIndex :: Prim () Word32
  CurrentIsPegin :: Prim () Bit
  CurrentPrevOutpoint :: Prim () (Word256,Word32)
  CurrentAsset :: Prim () (Conf Word256)
  CurrentAmount :: Prim () (Conf Word64)
  CurrentScriptHash :: Prim () Word256
  CurrentSequence :: Prim () Word32
  CurrentReissuanceBlinding :: Prim () (S Word256)
  CurrentNewIssuanceContract :: Prim () (S Word256)
  CurrentReissuanceEntropy :: Prim () (S Word256)
  CurrentIssuanceAssetAmt :: Prim () (S (Conf Word64))
  CurrentIssuanceTokenAmt :: Prim () (S (Conf Word64))
  CurrentIssuanceAssetProof :: Prim () Word256
  CurrentIssuanceTokenProof :: Prim () Word256
  TapleafVersion :: Prim () Word8
  Tapbranch :: Prim Word8 (S Word256)
  InternalKey :: Prim () PubKey
  AnnexHash :: Prim () (S Word256)
  NumOutputs :: Prim () Word32
  OutputAsset :: Prim Word32 (S (Conf Word256))
  OutputAmount :: Prim Word32 (S (Conf Word64))
  OutputNonce :: Prim Word32 (S (S (Conf Word256)))
  OutputScriptHash :: Prim Word32 (S Word256)
  OutputNullDatum :: Prim (Word32, Word32) (S (S (Either (Word2, Word256) (Either Bit Word4))))
  OutputSurjectionProof :: Prim Word32 (S Word256)
  OutputRangeProof :: Prim Word32 (S Word256)
  Fee :: Prim Word256 Word64
  ScriptCMR :: Prim () Word256

instance Eq (Prim a b) where
  Version == Version = True
  LockTime == LockTime = True
  InputsHash == InputsHash = True
  OutputsHash == OutputsHash = True
  NumInputs == NumInputs = True
  InputIsPegin == InputIsPegin = True
  InputPrevOutpoint == InputPrevOutpoint = True
  InputAsset == InputAsset = True
  InputAmount == InputAmount = True
  InputScriptHash == InputScriptHash = True
  InputSequence == InputSequence = True
  InputReissuanceBlinding == InputReissuanceBlinding = True
  InputNewIssuanceContract == InputNewIssuanceContract = True
  InputReissuanceEntropy == InputReissuanceEntropy = True
  InputIssuanceAssetAmt == InputIssuanceAssetAmt = True
  InputIssuanceTokenAmt == InputIssuanceTokenAmt = True
  InputIssuanceAssetProof == InputIssuanceAssetProof = True
  InputIssuanceTokenProof == InputIssuanceTokenProof = True
  CurrentIndex == CurrentIndex = True
  CurrentIsPegin == CurrentIsPegin = True
  CurrentPrevOutpoint == CurrentPrevOutpoint = True
  CurrentAsset == CurrentAsset = True
  CurrentAmount == CurrentAmount = True
  CurrentScriptHash == CurrentScriptHash = True
  CurrentSequence == CurrentSequence = True
  CurrentReissuanceBlinding == CurrentReissuanceBlinding = True
  CurrentNewIssuanceContract == CurrentNewIssuanceContract = True
  CurrentReissuanceEntropy == CurrentReissuanceEntropy = True
  CurrentIssuanceAssetAmt == CurrentIssuanceAssetAmt = True
  CurrentIssuanceTokenAmt == CurrentIssuanceTokenAmt = True
  CurrentIssuanceAssetProof == CurrentIssuanceAssetProof = True
  CurrentIssuanceTokenProof == CurrentIssuanceTokenProof = True
  TapleafVersion == TapleafVersion = True
  Tapbranch == Tapbranch = True
  InternalKey == InternalKey = True
  AnnexHash == AnnexHash = True
  NumOutputs == NumOutputs = True
  OutputAsset == OutputAsset = True
  OutputAmount == OutputAmount = True
  OutputNonce == OutputNonce = True
  OutputScriptHash == OutputScriptHash = True
  OutputNullDatum == OutputNullDatum = True
  OutputSurjectionProof == OutputSurjectionProof = True
  OutputRangeProof == OutputRangeProof = True
  Fee == Fee = True
  ScriptCMR == ScriptCMR = True
  _ == _ = False

primPrefix :: String
primPrefix = "Elements"

-- Consider deriving Show instead?
primName :: Prim a b -> String
primName Version = "version"
primName LockTime = "lockTime"
primName InputsHash = "inputsHash"
primName OutputsHash = "outputsHash"
primName NumInputs = "numInputs"
primName InputIsPegin = "inputIsPegin"
primName InputPrevOutpoint = "inputPrevOutpoint"
primName InputAsset = "inputAsset"
primName InputAmount = "inputAmount"
primName InputScriptHash = "inputScriptHash"
primName InputSequence = "inputSequence"
primName InputReissuanceBlinding = "inputReissuanceBlinding"
primName InputNewIssuanceContract = "inputNewIssuanceContract"
primName InputReissuanceEntropy = "inputReissuanceEntropy"
primName InputIssuanceAssetAmt = "inputIssuanceAssetAmt"
primName InputIssuanceTokenAmt = "inputIssuanceTokenAmt"
primName InputIssuanceAssetProof = "inputIssuanceAssetProof"
primName InputIssuanceTokenProof = "inputIssuanceTokenProof"
primName CurrentIndex = "currentIndex"
primName CurrentIsPegin = "currentIsPegin"
primName CurrentPrevOutpoint = "currentPrevOutpoint"
primName CurrentAsset = "currentAsset"
primName CurrentAmount = "currentAmount"
primName CurrentScriptHash = "currentScriptHash"
primName CurrentSequence = "currentSequence"
primName CurrentReissuanceBlinding = "currentReissuanceBlinding"
primName CurrentNewIssuanceContract = "currentNewIssuanceContract"
primName CurrentReissuanceEntropy = "currentReissuanceEntropy"
primName CurrentIssuanceAssetAmt = "currentIssuanceAssetAmt"
primName CurrentIssuanceTokenAmt = "currentIssuanceTokenAmt"
primName CurrentIssuanceAssetProof = "currentIssuanceAssetProof"
primName CurrentIssuanceTokenProof = "currentIssuanceTokenProof"
primName TapleafVersion = "tapleafVersion"
primName Tapbranch = "tapbranch"
primName InternalKey = "internalKey"
primName AnnexHash = "annexHash"
primName NumOutputs = "numOutputs"
primName OutputAsset = "outputAsset"
primName OutputAmount = "outputAmount"
primName OutputNonce = "outputNonce"
primName OutputScriptHash = "outputScriptHash"
primName OutputNullDatum = "outputNullDatum"
primName OutputSurjectionProof = "outputSurjectionProof"
primName OutputRangeProof = "outputRangeProof"
primName Fee = "fee"
primName ScriptCMR = "scriptCMR"

getPrimBit :: Monad m => m Bool -> m (SomeArrow Prim)
getPrimBit next =
  (((((makeArrow Version & makeArrow LockTime) & makeArrow InputIsPegin) & ((makeArrow InputPrevOutpoint & makeArrow InputAsset) & makeArrow InputAmount)) &
    (((makeArrow InputScriptHash & makeArrow InputSequence) & makeArrow InputReissuanceBlinding) & ((makeArrow InputNewIssuanceContract & makeArrow InputReissuanceEntropy) & makeArrow InputIssuanceAssetAmt))) &
   ((((makeArrow InputIssuanceTokenAmt & makeArrow InputIssuanceAssetProof) & makeArrow InputIssuanceTokenProof) & ((makeArrow OutputAsset & makeArrow OutputAmount) & makeArrow OutputNonce)) &
    (((makeArrow OutputScriptHash & makeArrow OutputNullDatum) & makeArrow OutputSurjectionProof) & (makeArrow OutputRangeProof & makeArrow ScriptCMR)))) &
  (((((makeArrow CurrentIndex & makeArrow CurrentIsPegin) & makeArrow CurrentPrevOutpoint) & ((makeArrow CurrentAsset & makeArrow CurrentAmount) & makeArrow CurrentScriptHash)) &
    (((makeArrow CurrentSequence & makeArrow CurrentReissuanceBlinding) & makeArrow CurrentNewIssuanceContract) & ((makeArrow CurrentReissuanceEntropy & makeArrow CurrentIssuanceAssetAmt) & makeArrow CurrentIssuanceTokenAmt))) &
   ((((makeArrow CurrentIssuanceAssetProof & makeArrow CurrentIssuanceTokenProof ) & makeArrow TapleafVersion) & ((makeArrow Tapbranch & makeArrow InternalKey) & makeArrow AnnexHash)) &
    (((makeArrow InputsHash & makeArrow OutputsHash) & makeArrow NumInputs) & (makeArrow NumOutputs & makeArrow Fee))))
 where
  l & r = next >>= \b -> if b then r else l
  makeArrow p = return (SomeArrow p)

putPrimBit :: Prim a b -> DList Bool
putPrimBit = go
 where
  go :: Prim a b -> DList Bool
  go Version                      = ([o,o,o,o,o,o]++)
  go LockTime                     = ([o,o,o,o,o,i]++)
  go InputIsPegin                 = ([o,o,o,o,i]++)
  go InputPrevOutpoint            = ([o,o,o,i,o,o]++)
  go InputAsset                   = ([o,o,o,i,o,i]++)
  go InputAmount                  = ([o,o,o,i,i]++)
  go InputScriptHash              = ([o,o,i,o,o,o]++)
  go InputSequence                = ([o,o,i,o,o,i]++)
  go InputReissuanceBlinding      = ([o,o,i,o,i]++)
  go InputNewIssuanceContract     = ([o,o,i,i,o,o]++)
  go InputReissuanceEntropy       = ([o,o,i,i,o,i]++)
  go InputIssuanceAssetAmt        = ([o,o,i,i,i]++)
  go InputIssuanceTokenAmt        = ([o,i,o,o,o,o]++)
  go InputIssuanceAssetProof      = ([o,i,o,o,o,i]++)
  go InputIssuanceTokenProof      = ([o,i,o,o,i]++)
  go OutputAsset                  = ([o,i,o,i,o,o]++)
  go OutputAmount                 = ([o,i,o,i,o,i]++)
  go OutputNonce                  = ([o,i,o,i,i]++)
  go OutputScriptHash             = ([o,i,i,o,o,o]++)
  go OutputNullDatum              = ([o,i,i,o,o,i]++)
  go OutputSurjectionProof        = ([o,i,i,o,i]++)
  go OutputRangeProof             = ([o,i,i,i,o]++)
  go ScriptCMR                    = ([o,i,i,i,i]++)
  go CurrentIndex                 = ([i,o,o,o,o,o]++)
-- :TODO: Below here are primitives that are likely candidates for being jets instead of primitives (see https://github.com/ElementsProject/simplicity/issues/5).
  go CurrentIsPegin               = ([i,o,o,o,o,i]++)
  go CurrentPrevOutpoint          = ([i,o,o,o,i]++)
  go CurrentAsset                 = ([i,o,o,i,o,o]++)
  go CurrentAmount                = ([i,o,o,i,o,i]++)
  go CurrentScriptHash            = ([i,o,o,i,i]++)
  go CurrentSequence              = ([i,o,i,o,o,o]++)
  go CurrentReissuanceBlinding    = ([i,o,i,o,o,i]++)
  go CurrentNewIssuanceContract   = ([i,o,i,o,i]++)
  go CurrentReissuanceEntropy     = ([i,o,i,i,o,o]++)
  go CurrentIssuanceAssetAmt      = ([i,o,i,i,o,i]++)
  go CurrentIssuanceTokenAmt      = ([i,o,i,i,i]++)
  go CurrentIssuanceAssetProof    = ([i,i,o,o,o,o]++)
  go CurrentIssuanceTokenProof    = ([i,i,o,o,o,i]++)
  go TapleafVersion               = ([i,i,o,o,i]++)
  go Tapbranch                    = ([i,i,o,i,o,o]++)
  go InternalKey                  = ([i,i,o,i,o,i]++)
  go AnnexHash                    = ([i,i,o,i,i]++)
  go InputsHash                   = ([i,i,i,o,o,o]++)
  go OutputsHash                  = ([i,i,i,o,o,i]++)
  go NumInputs                    = ([i,i,i,o,i]++)
  go NumOutputs                   = ([i,i,i,i,o]++)
  go Fee                          = ([i,i,i,i,i]++)
  (o,i) = (False, True)

data PrimEnv = PrimEnv { -- envParentGenesisBlockHash :: Hash256
                         envTx :: SigTx
                       , envIx :: Data.Word.Word32
                       , envTap :: TapEnv
                       , envScriptCMR :: Hash256
                       , envInputsHash :: Hash256
                       , envOutputsHash :: Hash256
                       }

instance Show PrimEnv where
  showsPrec d env = showParen (d > 10)
                  $ showString "primEnv "
                  . showsPrec 11 (envTx env)
                  . showString " "
                  . showsPrec 11 (envIx env)
                  . showString " "
                  . showsPrec 11 (envTap env)
                  . showString " "
                  . showsPrec 11 (envScriptCMR env)

primEnv :: SigTx -> Data.Word.Word32 -> TapEnv -> Hash256 -> Maybe PrimEnv
primEnv tx ix tap scmr | cond = Just $ PrimEnv { envTx = tx
                                               , envIx = ix
                                               , envTap = tap
                                               , envScriptCMR = scmr
                                               , envInputsHash = sigTxInputsHash tx
                                               , envOutputsHash = sigTxOutputsHash tx
                                               }
                   | otherwise = Nothing
 where
  cond = fromIntegral ix < Vector.length (sigTxIn tx)

primSem :: Prim a b -> a -> PrimEnv -> Maybe b
primSem p a env = interpret p a
 where
  tx = envTx env
  ix = envIx env
  lookupInput = (sigTxIn tx !?) . fromIntegral
  lookupOutput = (sigTxOut tx !?) . fromIntegral
  currentInput = lookupInput ix
  maxInput = fromIntegral $ Vector.length (sigTxIn tx) - 1
  maxOutput = fromIntegral $ Vector.length (sigTxOut tx) - 1
  cast :: Maybe a -> Either () a
  cast (Just x) = Right x
  cast Nothing = Left ()
  element :: a -> () -> a
  element = const
  atInput :: (SigTxInput -> a) -> Word32 -> Either () a
  atInput f = cast . fmap f . lookupInput . fromInteger . fromWord32
  atOutput :: (TxOutput -> a) -> Word32 -> Either () a
  atOutput f = cast . fmap f . lookupOutput . fromInteger . fromWord32
  encodeHash = toWord256 . integerHash256
  encodeConfidential enc (Explicit a) = Right (enc a)
  encodeConfidential enc (Confidential (Point by x) ()) = Left (toBit by, toWord256 . Schnorr.fe_repr $ x)
  encodeAsset = encodeConfidential encodeHash . view (under asset)
  encodeAmount = encodeConfidential (toWord64 . toInteger) . view (under amount)
  encodeNonce = cast . fmap (encodeConfidential encodeHash . nonce)
  encodeOutpoint op = (encodeHash $ opHash op, toWord32 . fromIntegral $ opIndex op)
  encodeKey (Schnorr.PubKey x) = toWord256 . toInteger $ x
  encodeNullDatum (Immediate h) = Left (toWord2 0, encodeHash h)
  encodeNullDatum (PushData h) = Left (toWord2 1, encodeHash h)
  encodeNullDatum (PushData2 h) = Left (toWord2 2, encodeHash h)
  encodeNullDatum (PushData4 h) = Left (toWord2 3, encodeHash h)
  encodeNullDatum OP1Negate = Right (Left (toBit False))
  encodeNullDatum OPReserved = Right (Left (toBit True))
  encodeNullDatum OP1  = Right (Right (toWord4 0x0))
  encodeNullDatum OP2  = Right (Right (toWord4 0x1))
  encodeNullDatum OP3  = Right (Right (toWord4 0x2))
  encodeNullDatum OP4  = Right (Right (toWord4 0x3))
  encodeNullDatum OP5  = Right (Right (toWord4 0x4))
  encodeNullDatum OP6  = Right (Right (toWord4 0x5))
  encodeNullDatum OP7  = Right (Right (toWord4 0x6))
  encodeNullDatum OP8  = Right (Right (toWord4 0x7))
  encodeNullDatum OP9  = Right (Right (toWord4 0x8))
  encodeNullDatum OP10 = Right (Right (toWord4 0x9))
  encodeNullDatum OP11 = Right (Right (toWord4 0xa))
  encodeNullDatum OP12 = Right (Right (toWord4 0xb))
  encodeNullDatum OP13 = Right (Right (toWord4 0xc))
  encodeNullDatum OP14 = Right (Right (toWord4 0xd))
  encodeNullDatum OP15 = Right (Right (toWord4 0xe))
  encodeNullDatum OP16 = Right (Right (toWord4 0xf))
  issuanceAmount = either newIssuanceAmount reissuanceAmount
  issuanceTokenAmount = either newIssuanceTokenAmount (const (Amount (Explicit 0)))
  interpret Version = element . return . toWord32 . toInteger $ sigTxVersion tx
  interpret LockTime = element . return . toWord32 . toInteger $ sigTxLock tx
  interpret InputsHash = element . return . encodeHash $ envInputsHash env
  interpret OutputsHash = element . return . encodeHash $ envOutputsHash env
  interpret NumInputs = element . return . toWord32 . toInteger $ 1 + maxInput
  interpret InputIsPegin = return . (atInput $ toBit . sigTxiIsPegin)
  interpret InputPrevOutpoint = return . (atInput $ encodeOutpoint . sigTxiPreviousOutpoint)
  interpret InputAsset = return . (atInput $ encodeAsset . utxoAsset . sigTxiTxo)
  interpret InputAmount = return . (atInput $ encodeAmount . utxoAmount . sigTxiTxo)
  interpret InputScriptHash = return . (atInput $ encodeHash . bslHash . utxoScript . sigTxiTxo)
  interpret InputSequence = return . (atInput $ toWord32 . toInteger . sigTxiSequence)
  interpret InputReissuanceBlinding = return . (atInput $
      cast . fmap encodeHash . (either (const Nothing) (Just . reissuanceBlindingNonce) <=< sigTxiIssuance))
  interpret InputNewIssuanceContract = return . (atInput $
      cast . fmap encodeHash . (either (Just . newIssuanceContractHash) (const Nothing) <=< sigTxiIssuance))
  interpret InputReissuanceEntropy = return . (atInput $
      cast . fmap encodeHash . (either (const Nothing) (Just . reissuanceEntropy) <=< sigTxiIssuance))
  interpret InputIssuanceAssetAmt = return . (atInput $
      cast . fmap (encodeAmount . clearAmountPrf . issuanceAmount) . sigTxiIssuance)
  interpret InputIssuanceTokenAmt = return . (atInput $
      cast . fmap (encodeAmount . clearAmountPrf . issuanceTokenAmount) . sigTxiIssuance)
  interpret InputIssuanceAssetProof = return . (atInput $ encodeHash . bslHash . view (to sigTxiIssuance.just_.to issuanceAmount.under amount.prf_))
  interpret InputIssuanceTokenProof = return . (atInput $ encodeHash . bslHash . view (to sigTxiIssuance.just_.to issuanceTokenAmount.under amount.prf_))
  interpret CurrentIndex = element . return . toWord32 . toInteger $ ix
  interpret CurrentIsPegin = element $ toBit . sigTxiIsPegin <$> currentInput
  interpret CurrentPrevOutpoint = element $ encodeOutpoint . sigTxiPreviousOutpoint <$> currentInput
  interpret CurrentAsset = element $ encodeAsset . utxoAsset . sigTxiTxo <$> currentInput
  interpret CurrentAmount = element $ encodeAmount . utxoAmount . sigTxiTxo <$> currentInput
  interpret CurrentScriptHash = element $ encodeHash . bslHash . utxoScript . sigTxiTxo <$> currentInput
  interpret CurrentSequence = element $ toWord32 . toInteger . sigTxiSequence <$> currentInput
  interpret CurrentReissuanceBlinding = element $
      cast . fmap encodeHash . (either (const Nothing) (Just . reissuanceBlindingNonce) <=< sigTxiIssuance) <$> currentInput
  interpret CurrentNewIssuanceContract = element $
      cast . fmap encodeHash . (either (Just . newIssuanceContractHash) (const Nothing) <=< sigTxiIssuance) <$> currentInput
  interpret CurrentReissuanceEntropy = element $
      cast . fmap encodeHash . (either (const Nothing) (Just . reissuanceEntropy) <=< sigTxiIssuance) <$> currentInput
  interpret CurrentIssuanceAssetAmt = element $
      cast . fmap (encodeAmount . clearAmountPrf . issuanceAmount) . sigTxiIssuance <$> currentInput
  interpret CurrentIssuanceTokenAmt = element $
      cast . fmap (encodeAmount . clearAmountPrf . issuanceTokenAmount) . sigTxiIssuance <$> currentInput
  interpret CurrentIssuanceAssetProof = element $ encodeHash . bslHash . view (to sigTxiIssuance.just_.to issuanceAmount.under amount.prf_) <$> currentInput
  interpret CurrentIssuanceTokenProof = element $ encodeHash . bslHash . view (to sigTxiIssuance.just_.to issuanceTokenAmount.under amount.prf_) <$> currentInput
  interpret TapleafVersion = element . return . toWord8 . toInteger . tapLeafVersion $ envTap env
  interpret Tapbranch = return . cast . fmap encodeHash . listToMaybe . flip drop (tapBranch (envTap env)) . fromInteger . fromWord8
  interpret InternalKey = element . return . encodeKey . tapInternalKey $ envTap env
  interpret AnnexHash = element . return . cast $ encodeHash . bslHash <$> tapAnnex (envTap env)
  interpret NumOutputs = element . return . toWord32 . toInteger $ 1 + maxOutput
  interpret OutputAsset = return . (atOutput $ encodeAsset . clearAssetPrf . txoAsset)
  interpret OutputAmount = return . (atOutput $ encodeAmount . clearAmountPrf . txoAmount)
  interpret OutputNonce = return . (atOutput $ encodeNonce . txoNonce)
  interpret OutputScriptHash = return . (atOutput $ encodeHash . bslHash . txoScript)
  interpret OutputNullDatum = \(i, j) -> return . cast $ do
    txo <- lookupOutput . fromInteger $ fromWord32 i
    nullData <- txNullData $ txoScript txo
    return . cast . fmap (encodeNullDatum . fmap bslHash) . listToMaybe $ List.drop (fromInteger (fromWord32 j)) nullData
  interpret OutputSurjectionProof = return . (atOutput $ encodeHash . bslHash . view (to txoAsset.under asset.prf_))
  interpret OutputRangeProof = return . (atOutput $ encodeHash . bslHash . view (to txoAmount.under amount.prf_))
  interpret Fee = \assetId -> return . toWord64 . toInteger . Monoid.getSum $ foldMap (getValue assetId) (sigTxOut tx)
   where
    getValue assetId txo = fromMaybe (Monoid.Sum 0) $ do
      guard $ BSL.null (txoScript txo)
      Explicit a <- Just . view (under asset) $ txoAsset txo
      guard $ assetId == encodeHash a
      Explicit v <- Just . view (under amount) $ txoAmount txo
      return (Monoid.Sum v)
  interpret ScriptCMR = element . return . encodeHash $ envScriptCMR env

getPrimByte :: Data.Word.Word8 -> Get (Maybe (SomeArrow Prim))
getPrimByte = error "Simplicity.Elements.Primitive.getPrimByte is not implemented"

putPrimByte :: Putter (Prim a b)
putPrimByte = error "Simplicity.Elements.Primitive.putPrimByte is not implemented"

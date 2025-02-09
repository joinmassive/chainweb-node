{-# LANGUAGE BangPatterns #-}

-- |
-- Module      :  Chainweb.Pact.Service.BlockValidation
-- Copyright   :  Copyright © 2018 Kadena LLC.
-- License     :  (see the file LICENSE)
-- Maintainer  :  Emily Pillmore <emily@kadena.io>
-- Stability   :  experimental
--
-- The block validation logic for Pact Service
--
-- This exists due to moving things around resolving
-- chainweb dependencies. This should find a new home.
--
module Chainweb.Pact.Service.BlockValidation
( validateBlock
, newBlock
, local
, lookupPactTxs
, pactPreInsertCheck
, pactBlockTxHistory
, pactHistoricalLookup
, pactSyncToBlock
) where


import Control.Concurrent.MVar.Strict

import Data.Vector (Vector)
import Data.HashMap.Strict (HashMap)

import Pact.Types.Hash
import Pact.Types.Persistence (RowKey, TxLog, Domain)
import Pact.Types.RowData (RowData)

import Chainweb.BlockHash
import Chainweb.BlockHeader
import Chainweb.BlockHeight
import Chainweb.Mempool.Mempool (InsertError)
import Chainweb.Miner.Pact
import Chainweb.Pact.Service.PactQueue
import Chainweb.Pact.Service.Types
import Chainweb.Payload
import Chainweb.Transaction
import Chainweb.Utils (T2)


newBlock :: Miner -> ParentHeader -> PactQueue ->
            IO (MVar (Either PactException PayloadWithOutputs))
newBlock mi bHeader reqQ = do
    !resultVar <- newEmptyMVar :: IO (MVar (Either PactException PayloadWithOutputs))
    let !msg = NewBlockMsg NewBlockReq
          { _newBlockHeader = bHeader
          , _newMiner = mi
          , _newResultVar = resultVar }
    addRequest reqQ msg
    return resultVar

validateBlock
    :: BlockHeader
    -> PayloadData
    -> PactQueue
    -> IO (MVar (Either PactException PayloadWithOutputs))
validateBlock bHeader plData reqQ = do
    !resultVar <- newEmptyMVar :: IO (MVar (Either PactException PayloadWithOutputs))
    let !msg = ValidateBlockMsg ValidateBlockReq
          { _valBlockHeader = bHeader
          , _valResultVar = resultVar
          , _valPayloadData = plData }
    addRequest reqQ msg
    return resultVar

local
    :: Maybe LocalPreflightSimulation
    -> Maybe LocalSignatureVerification
    -> Maybe RewindDepth
    -> ChainwebTransaction
    -> PactQueue
    -> IO (MVar (Either PactException LocalResult))
local preflight sigVerify rd ct reqQ = do
    !resultVar <- newEmptyMVar
    let !msg = LocalMsg LocalReq
          { _localRequest = ct
          , _localPreflight = preflight
          , _localSigVerification = sigVerify
          , _localRewindDepth = rd
          , _localResultVar = resultVar }
    addRequest reqQ msg
    return resultVar

lookupPactTxs
    :: Rewind
    -> Maybe ConfirmationDepth
    -> Vector PactHash
    -> PactQueue
    -> IO (MVar (Either PactException (HashMap PactHash (T2 BlockHeight BlockHash))))
lookupPactTxs restorePoint confDepth txs reqQ = do
    resultVar <- newEmptyMVar
    let !req = LookupPactTxsReq restorePoint confDepth txs resultVar
    let !msg = LookupPactTxsMsg req
    addRequest reqQ msg
    return resultVar

pactPreInsertCheck
    :: Vector ChainwebTransaction
    -> PactQueue
    -> IO (MVar (Either PactException (Vector (Either InsertError ()))))
pactPreInsertCheck txs reqQ = do
    resultVar <- newEmptyMVar
    let !req = PreInsertCheckReq txs resultVar
    let !msg = PreInsertCheckMsg req
    addRequest reqQ msg
    return resultVar

pactBlockTxHistory
  :: BlockHeader
  -> Domain RowKey RowData
  -> PactQueue
  -> IO (MVar (Either PactException BlockTxHistory))
pactBlockTxHistory bh d reqQ = do
  resultVar <- newEmptyMVar
  let !req = BlockTxHistoryReq bh d resultVar
  let !msg = BlockTxHistoryMsg req
  addRequest reqQ msg
  return resultVar

pactHistoricalLookup
    :: BlockHeader
    -> Domain RowKey RowData
    -> RowKey
    -> PactQueue
    -> IO (MVar (Either PactException (Maybe (TxLog RowData))))
pactHistoricalLookup bh d k reqQ = do
  resultVar <- newEmptyMVar
  let !req = HistoricalLookupReq bh d k resultVar
  let !msg = HistoricalLookupMsg req
  addRequest reqQ msg
  return resultVar

pactSyncToBlock
    :: BlockHeader
    -> PactQueue
    -> IO (MVar (Either PactException ()))
pactSyncToBlock bh reqQ = do
    !resultVar <- newEmptyMVar
    let !msg = SyncToBlockMsg SyncToBlockReq
          { _syncToBlockHeader = bh
          , _syncToResultVar = resultVar
          }
    addRequest reqQ msg
    return resultVar

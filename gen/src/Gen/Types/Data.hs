{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE TemplateHaskell   #-}

-- Module      : Gen.Types.Data
-- Copyright   : (c) 2013-2018 Brendan Hay
-- License     : This Source Code Form is subject to the terms of
--               the Mozilla xtPublic License, v. 2.0.
--               A copy of the MPL can be found in the LICENSE file or
--               you can obtain it at http://mozilla.org/MPL/2.0/.
-- Maintainer  : Brendan Hay <brendan.g.hay+amazonka@gmail.com>
-- Stability   : provisional
-- Portability : non-portable (GHC extensions)

module Gen.Types.Data where

import Control.Lens hiding ((.=))

import Data.Aeson
import Data.Aeson.Types
import Data.Function    (on)
import Data.Text        (Text)

import Gen.Types.Ann
import Gen.Types.Help
import Gen.Types.Id
import Gen.Types.Map
import Gen.Types.TypeOf

import qualified Data.Text      as Text
import qualified Data.Text.Lazy as LText

type Rendered = LText.Text

data Fun = Fun'
    { _funName :: Text
    , _funDoc  :: Help
    , _funSig  ::  Rendered
    , _funDecl :: Rendered
    } deriving (Eq, Show)

instance ToJSON Fun where
    toJSON Fun'{..} = object
        [ "type"          .= Text.pack "function"
        , "name"          .= _funName
        , "documentation" .= _funDoc
        , "signature"     .= _funSig
        , "declaration"   .= _funDecl
        ]

data Prod = Prod'
    { _prodName   :: Text
    , _prodDoc    :: Maybe Help
    , _prodDecl   :: Rendered
    , _prodCtor   :: Fun
    , _prodLenses :: [Fun]
    } deriving (Eq, Show)

prodToJSON :: ToJSON a => Solved -> Prod -> Map Text a -> [Pair]
prodToJSON s Prod'{..} is =
    [ "type"          .= Text.pack "product"
    , "name"          .= _prodName
    , "constructor"   .= _prodCtor
    , "documentation" .= _prodDoc
    , "declaration"   .= _prodDecl
    , "lenses"        .= map flatten _prodLenses
    , "instances"     .= is
    , "shared"        .= isShared s
    , "eq"            .= isEq s
    ]
  where
    flatten fun = fun { _funDoc = go (_funDoc fun) }
      where
        go (Help h) = Help (Text.replace "\n--" "" h)

data Sum = Sum'
    { _sumName  :: Text
    , _sumDoc   :: Maybe Help
    , _sumDecl  :: Rendered
    , _sumCtors :: Map Text Text
    } deriving (Eq, Show)

sumToJSON :: Solved -> Sum -> [Text] -> [Pair]
sumToJSON s Sum'{..} is =
    [ "type"          .= Text.pack "sum"
    , "name"          .= _sumName
    , "constructors"  .= _sumCtors
    , "documentation" .= _sumDoc
    , "declaration"   .= _sumDecl
    , "instances"     .= is
    , "shared"        .= isShared s
    , "eq"            .= True
    ]

data Gen = Gen'
    { _genName :: Text
    , _genDoc  :: Maybe Help
    , _genDecl :: Rendered
    } deriving (Eq, Show)

instance ToJSON Gen where
    toJSON Gen'{..} = object
        [ "type"          .= Text.pack "error"
        , "name"          .= _genName
        , "documentation" .= _genDoc
        , "declaration"   .= _genDecl
        ]

data SData
    = Prod !Solved Prod (Map Text Rendered)
      -- ^ A product type (record).
    | Sum  !Solved Sum  [Text]
      -- ^ A nullary sum type.
    | Fun  Fun
      -- ^ A function declaration.
      deriving (Eq, Show)

instance Ord SData where
    compare a b =
        case (a, b) of
            (Prod _ x _, Prod _ y _) -> on compare _prodName x y
            (Sum  _ x _, Sum  _ y _) -> on compare _sumName  x y
            (Fun  _,     Fun  _)     -> EQ
            (Prod {},    _)          -> GT
            (_,          Prod {})    -> LT
            (Sum  {},    _)          -> GT
            (_,          Sum  {})    -> LT

instance ToJSON SData where
    toJSON = \case
        Prod s x  is -> object (prodToJSON s x  is)
        Sum  s st is -> object (sumToJSON  s st is)
        Fun  f       -> toJSON f

instance HasId SData where
    identifier = \case
        Prod _ p _         -> mkId (_prodName p)
        Sum  _ s _         -> mkId (_sumName  s)
        Fun (Fun' n _ _ _) -> mkId n

data WData = WData
    { _waitName   :: Text
    , _waitOpName :: Id
    , _waitCtor   :: Fun
    } deriving (Show)

makeLenses ''WData

instance ToJSON WData where
    toJSON (WData n _ c) = object
        [ "name"        .= n
        , "constructor" .= c
        ]

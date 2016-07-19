module Kyckling.FOOL.Smart (
  module Kyckling.FOOL.Smart,
  Var(..), Identifier, Definition(..), Binding(..), Term, Formula
) where

import qualified Data.List.NonEmpty as NE
import Data.List.NonEmpty (NonEmpty)

import Data.Either

import Kyckling.FOOL
import Kyckling.FOOL.Tuple

-- Definition
tupleD :: NonEmpty Identifier -> Definition
tupleD = either (flip Symbol []) TupleD . nonUnit

-- Term
integerConstant = IntegerConstant
booleanConstant = BooleanConstant

constant :: Identifier -> Term
constant = flip Application []

variable = Variable
application = Application
binary = Binary
unary = Unary
quantify = Quantify
equals = Equals

let_ :: Binding -> Term -> Term
let_ (Binding (Symbol c []) b) (Application c' []) | c == c' = b
let_ (Binding (Symbol c []) b) (Right_ t (Application c' [])) | c == c' = Right_ t b
let_ (Binding (Symbol c []) b) (Left_  (Application c' []) t) | c == c' = Left_  b t
let_ (Binding (Symbol c []) b) (Just_  (Application c' []))   | c == c' = Just_  b
let_ b t = Let b t

if_ = If
select = Select
store = Store

tupleLiteral :: NonEmpty Term -> Term
tupleLiteral = either id TupleLiteral . nonUnit

nothing = Nothing_
just = Just_
isJust = IsJust
fromJust = FromJust
left = Left_
right = Right_
isLeft = IsLeft
fromLeft = FromLeft
fromRight = FromRight
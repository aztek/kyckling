module Kyckling.Program where

import Kyckling.Theory
import qualified Kyckling.FOOL as F

type Var = Typed Name
type Function = Typed Name

data LValue = Variable Var
            | ArrayElem Var Expression
  deriving (Show)

instance TypeOf LValue where
  typeOf (Variable  v) = typeOf v
  typeOf (ArrayElem v _) = arrayArgument (typeOf v)

data Expression = IntegerLiteral Integer
                | BooleanLiteral Bool
                | Ref LValue
                | Unary  UnaryOp    Expression
                | Binary BinaryOp   Expression Expression
                | IfElse Expression Expression Expression
                | FunApp Function [Expression]
                | Equals Sign Expression Expression
  deriving (Show)

instance TypeOf Expression where
  typeOf (IntegerLiteral _) = Integer
  typeOf (BooleanLiteral _) = Boolean
  typeOf (Ref lval) = typeOf lval
  typeOf (Unary op _) = unaryOpRange op
  typeOf (Binary op _ _) = binaryOpRange op
  typeOf (IfElse _ a _) = typeOf a
  typeOf (FunApp f _) = typeOf f
  typeOf (Equals{}) = Boolean

data Statement = Declare Var
               | Assign LValue Expression
               | If Expression NonTerminating (Either NonTerminating (Bool, Terminating))
  deriving (Show)

data NonTerminating = NonTerminating [Statement]
  deriving (Show)

data Terminating = Return    NonTerminating Expression
                 | IteReturn NonTerminating Expression Terminating Terminating
  deriving (Show)

instance TypeOf Terminating where
  typeOf (Return    _ e) = typeOf e
  typeOf (IteReturn _ _ a _) = typeOf a

data Assertion = Assertion F.Formula
  deriving (Show)

data FunDef = FunDef Type Name [Typed Name] Terminating
  deriving (Show)

data Program = Program [FunDef] NonTerminating [Assertion]
  deriving (Show)
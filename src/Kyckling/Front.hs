module Kyckling.Front where

import Control.Monad
import Control.Applicative
import Data.Maybe

import Kyckling.Theory
import Kyckling.Program
import Kyckling.Program.Pretty
import qualified Kyckling.Program.AST as AST

import qualified Kyckling.FOOL as F
import qualified Kyckling.FOOL.AST as FAST
import qualified Kyckling.FOOL.Pretty as FP

type Error = String

type Env = [(String, Type)]

emptyEnv :: Env
emptyEnv = []

lookupName :: String -> Env -> Either Error (Typed Name)
lookupName name env = case lookup name env of
                        Nothing  -> Left  ("undefined variable " ++ name)
                        Just typ -> Right (Typed name typ)

lookupArrayName :: String -> Env -> Either Error (Typed Name)
lookupArrayName name env = do Typed _ arr <- lookupName name env
                              case arr of
                                Array el  -> Right (Typed name el)
                                otherwise -> Left "not an array"

analyze :: AST.AST -> Either Error Program
analyze (AST.AST ss as) =
  do (env, ss') <- analyzeStmtList emptyEnv ss
     as' <- mapM (analyzeAssert env) as
     return (Program ss' as')

analyzeStmtList :: Env -> [AST.Stmt] -> Either Error (Env, [Statement])
analyzeStmtList env [] = Right (env, [])
analyzeStmtList env (s:ss) =
  do (env',  s')  <- analyzeStmt env s
     (env'', ss') <- analyzeStmtList env' ss
     return (env'', s' ++ ss')

analyzeStmt :: Env -> AST.Stmt -> Either Error (Env, [Statement])
analyzeStmt env (AST.Declare t defs) =
  do defs' <- mapM analyzeDef defs
     let env' = map (\(n, _) -> (n, t)) defs' ++ env
     let decl = concatMap toStmts defs'
     return (env', decl)
  where
    analyzeDef (n, e) = do e' <- mapM (analyzeExpr env t) (maybeToList e)
                           return (n, e')
    toStmts (n, e) = Declare v : map (Assign (Variable v)) e
      where v = Typed n t
analyzeStmt env (AST.If c a b) =
  do (_, a') <- analyzeStmtList env a
     (_, b') <- analyzeStmtList env b
     c' <- analyzeExpr env Boolean c
     return (env, [If c' a' b'])
analyzeStmt env (AST.Increment lval) =
  do lv <- analyzeLValue env Integer lval
     return (env, [Assign lv (Binary Add (Ref lv) (IntegerConst 1))])
analyzeStmt env (AST.Decrement lval) =
  do lv <- analyzeLValue env Integer lval
     return (env, [Assign lv (Binary Subtract (Ref lv) (IntegerConst 1))])
analyzeStmt env (AST.Update lval AST.Assign e) =
  do lv <- analyzeLValue' env lval
     e' <- analyzeExpr env (typeOf lv) e
     return (env, [Assign lv e'])
analyzeStmt env (AST.Update lval op e) =
  do lv <- analyzeLValue env d1 lval
     e' <- analyzeExpr env d2 e
     return (env, [Assign lv (Binary op' (Ref lv) e')])
  where
    op' = case op of
            AST.Add      -> Add
            AST.Subtract -> Subtract
            AST.Multiply -> Multiply
    (d1, d2) = binaryOpDomain op' -- we assume that d1 == range of op'

analyzeAssert :: Env -> AST.Assert -> Either Error Assertion
analyzeAssert env (AST.Assert f) = Assertion <$> analyzeFormula env f

analyzeFormula :: Env -> FAST.Term -> Either Error F.Formula
analyzeFormula env = analyzeTerm env Boolean

analyzeTerm :: Env -> Type -> FAST.Term -> Either Error F.Term
analyzeTerm env t term = do term' <- analyzeTerm' env term
                            let t' = typeOf term'
                            if t == t' then return term' else
                              Left $ "expected an expression of the type " ++ prettyType t' ++
                                     " but got " ++ FP.prettyTerm term' ++ " of the type " ++ prettyType t 

typesCoincide :: F.Term -> F.Term -> Either Error ()
typesCoincide a b = if t1 == t2 then Right ()
                                else Left "types mismatch"
  where
    t1 = typeOf a
    t2 = typeOf b

ofType :: F.Term -> Type -> Either Error ()
ofType a t = if t == typeOf a then Right ()
                                  else Left "type mismatch"


analyzeTerm' :: Env -> FAST.Term -> Either Error F.Term
analyzeTerm' env (FAST.IntConst  i) = return (F.IntegerConst i)
analyzeTerm' env (FAST.BoolConst b) = return (F.BooleanConst b)
analyzeTerm' env (FAST.Unary  op t) = F.Unary op <$> analyzeTerm env d t
  where
    d = unaryOpDomain op
analyzeTerm' env (FAST.Binary op a b) = F.Binary op <$> analyzeTerm env d1 a <*> analyzeTerm env d2 b
  where
    (d1, d2) = binaryOpDomain op
analyzeTerm' env (FAST.Ternary c a b) = 
  do c' <- analyzeTerm  env Boolean c
     a' <- analyzeTerm' env a
     b' <- analyzeTerm  env (typeOf a') b
     return (F.If c' a' b')
analyzeTerm' env (FAST.Eql a b) =
  do a' <- analyzeTerm' env a
     b' <- analyzeTerm  env (typeOf a') b
     return (F.Eql a' b')
analyzeTerm' env (FAST.InEql a b) =
  do a' <- analyzeTerm' env a
     b' <- analyzeTerm  env (typeOf a') b
     return (F.InEql a' b')
analyzeTerm' env (FAST.Quantified q vars term) = F.Quantify q vars' <$> analyzeTerm env' Boolean term
  where
    -- TODO: check that the variables are disjoint
    env' = map (\(Typed v t) -> (v, t)) vars ++ env
    vars' = map (fmap F.Var) vars
analyzeTerm' env (FAST.Constant  s)   = F.Const  <$> lookupName s env
analyzeTerm' env (FAST.ArrayElem s i) = F.Select <$> (F.Const <$> lookupArrayName s env) <*> analyzeTerm env Integer i


analyzeLValue :: Env -> Type -> AST.LVal -> Either Error LValue
analyzeLValue env t lval = do lval' <- analyzeLValue' env lval
                              let t' = typeOf lval'
                              if t == t' then return lval' else
                                Left $ "expected an expression of the type " ++ prettyType t' ++
                                       " but got " ++ prettyLValue lval' ++ " of the type " ++ prettyType t 

analyzeLValue' :: Env -> AST.LVal -> Either Error LValue
analyzeLValue' env (AST.Var s) = Variable <$> lookupName s env
analyzeLValue' env (AST.ArrayElem s i) = ArrayElem <$> lookupArrayName s env <*> analyzeExpr env Integer i

analyzeExpr :: Env -> Type -> AST.Expr -> Either Error Expression
analyzeExpr env t e = do e' <- analyzeExpr' env e
                         let t' = typeOf e'
                         if t == t' then return e' else
                           Left $ "expected an expression of the type " ++ prettyType t' ++
                                  " but got " ++ prettyExpression e' ++ " of the type " ++ prettyType t 

analyzeExpr' :: Env -> AST.Expr -> Either Error Expression
analyzeExpr' _ (AST.IntConst  i) = return (IntegerConst i)
analyzeExpr' _ (AST.BoolConst b) = return (BoolConst    b)
analyzeExpr' env (AST.LVal lval) = Ref <$> analyzeLValue' env lval
analyzeExpr' env (AST.Unary op e) = Unary op <$> analyzeExpr env d e
  where
    d = unaryOpDomain op
analyzeExpr' env (AST.Binary op a b) =
  do a' <- analyzeExpr env d1 a
     b' <- analyzeExpr env d2 b
     return (Binary op a' b')
  where
    (d1, d2) = binaryOpDomain op
analyzeExpr' env (AST.Eql a b) =
  do a' <- analyzeExpr' env a
     b' <- analyzeExpr  env (typeOf a') b
     return (Eql a' b')
analyzeExpr' env (AST.InEql a b) =
  do a' <- analyzeExpr' env a
     b' <- analyzeExpr  env (typeOf a') b
     return (InEql a' b')
analyzeExpr' env (AST.Ternary c a b) =
  do c' <- analyzeExpr  env Boolean c
     a' <- analyzeExpr' env a
     b' <- analyzeExpr  env (typeOf a') b
     return (IfElse c' a' b')
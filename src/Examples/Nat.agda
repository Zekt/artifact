{-# OPTIONS --safe --without-K --show-implicit #-}

module Examples.Nat where

open import Prelude

open import Generics.Telescope
open import Generics.Description
open import Generics.Reflection
open import Generics.Recursion

open import Generics.RecursionScheme

NatD = genDataD ℕ

-- [TODO] datatype wrapper

NatT : DataT NatD
NatT = `uncurry NatD ℕ

NatC = genDataC NatD ℕ  -- [FIXME]

-- [TODO] print function definitions directly

-- [TODO] fold wrapper & connection
unquoteDecl foldℕ = defineFold (fold-operator NatC) foldℕ  -- [FIXME]
-- [TODO] fold fusion

unquoteDecl indℕ = defineInd (ind-operator NatC) indℕ

{-# OPTIONS --without-K #-}

open import Prelude hiding (length)

module Metalib.Telescope where

open import Utils.Reflection
open import Utils.Error as Err

open import Generics.Telescope
open import Generics.Description

dprint = debugPrint "meta" 5

-- Frequently used terms
private
  _`∷_ : Term → Term → Term
  t `∷ u = con (quote Tel._∷_) (vArg t ∷ vArg u ∷ [])

  `[] : Term
  `[] = quoteTerm Tel.[]

--
fromTelType : Tel ℓ → Set ℓ′ → TC Type
fromTelType []      B = quoteTC! B
fromTelType (A ∷ T) B = caseM quoteTC! T of λ where
  (lam v (abs s _)) → extendContextT (visible-relevant-ω) A λ `A x → do
    vΠ[ s ∶ `A ]_ <$> fromTelType (T x) B
  t                 → Err.notλ t

-- ℕ is the length of (T : Tel ℓ)
-- this may fail if `Tel` is not built by λ by pattern matching lambdas.
fromTel : (T : Tel ℓ) → TC (ℕ × Telescope)
fromTel []      = return (0 , [])
fromTel (A ∷ T) = caseM quoteTC! T of λ where
  (lam v (abs s _)) → extendContextT (visible-relevant-ω) A λ `A x → do
    n , `Γ ← fromTel (T x) 
    return $ (suc n) , (s , vArg `A) ∷ `Γ 
  t                 → Err.notλ t

to`Tel : Telescope → Term
to`Tel = foldr `[] λ where
  (s , arg _ `A) `T →  `A `∷ vLam (abs s `T)

fromTelescope : Telescope → TC (Tel ℓ)
fromTelescope = unquoteTC ∘ to`Tel

-- extend the context in a TC computation 
extendContextTs : {A : Set ℓ′}
  → (T : Tel ℓ) → (⟦ T ⟧ᵗ → TC A) → TC A
extendContextTs []      f = f tt
extendContextTs (A ∷ T) f = extendContextT visible-relevant-ω A λ _ x →
  extendContextTs (T x) (curry f x)

extendContextℓs : {A : Set ℓ}
  → (#levels : ℕ) → (Level ^ #levels → TC A) → TC A
extendContextℓs zero    c = c tt
extendContextℓs (suc n) c = extendContextT hidden-relevant-ω Level λ _ ℓ →
    extendContextℓs n (curry c ℓ)

{-# OPTIONS --safe --without-K #-}

module Generics.Safe.Telescope where

open import Prelude

infixr 5 _∷_

data Tel : Level → Setω where
  []  : Tel lzero
  _∷_ : (A : Set ℓ) (T : A → Tel ℓ') → Tel (ℓ ⊔ ℓ')

-- de Bruijn's notation

∷-syntax : (A : Set ℓ) (T : A → Tel ℓ') → Tel (ℓ ⊔ ℓ')
∷-syntax = _∷_

syntax ∷-syntax A (λ x → T) = [ x ∶ A ] T

⟦_⟧ᵗ : Tel ℓ → Set ℓ
⟦ []    ⟧ᵗ = ⊤
⟦ A ∷ T ⟧ᵗ = Σ A λ a → ⟦ T a ⟧ᵗ

Curriedᵗ : (T : Tel ℓ) → (⟦ T ⟧ᵗ → Set ℓ') → Set (ℓ ⊔ ℓ')
Curriedᵗ []      X = X tt
Curriedᵗ (A ∷ T) X = (a : A) → Curriedᵗ (T a) (curry X a)

curryᵗ : (T : Tel ℓ) (X : ⟦ T ⟧ᵗ → Set ℓ') → ((t : ⟦ T ⟧ᵗ) → X t) → Curriedᵗ T X
curryᵗ []      X f = f tt
curryᵗ (A ∷ T) X f = λ a → curryᵗ (T a) (curry X a) (curry f a)

uncurryᵗ : (T : Tel ℓ) (X : ⟦ T ⟧ᵗ → Set ℓ') → Curriedᵗ T X → (t : ⟦ T ⟧ᵗ) → X t
uncurryᵗ []      X f tt      = f
uncurryᵗ (A ∷ T) X f (a , t) = uncurryᵗ (T a) (curry X a) (f a) t

snocᵗ : (T : Tel ℓ) → (⟦ T ⟧ᵗ → Set ℓ') → Tel (ℓ ⊔ ℓ')
snocᵗ []      B = B tt ∷ λ _ → []
snocᵗ (A ∷ T) B = A ∷ λ a → snocᵗ (T a) λ t → B (a , t)

snocᵗ-inj : {T : Tel ℓ} {A : ⟦ T ⟧ᵗ → Set ℓ'} → Σ ⟦ T ⟧ᵗ A → ⟦ snocᵗ T A ⟧ᵗ
snocᵗ-inj {T = []   } (_       , a) = a , tt
snocᵗ-inj {T = B ∷ T} ((b , t) , a) = b , snocᵗ-inj {T = T b} (t , a)

snocᵗ-proj : {T : Tel ℓ} {A : ⟦ T ⟧ᵗ → Set ℓ'} → ⟦ snocᵗ T A ⟧ᵗ → Σ ⟦ T ⟧ᵗ A
snocᵗ-proj {T = []   } (a , _) = tt , a
snocᵗ-proj {T = B ∷ T} (b , t) = let (t' , a) = snocᵗ-proj {T = T b} t in ((b , t') , a)

snocᵗ-proj-inj : {T : Tel ℓ} {A : ⟦ T ⟧ᵗ → Set ℓ'}
                 (p : Σ ⟦ T ⟧ᵗ A) → snocᵗ-proj (snocᵗ-inj p) ≡ p
snocᵗ-proj-inj {T = []   } (_       , a) = refl
snocᵗ-proj-inj {T = B ∷ T} ((b , t) , a) = cong (λ p → let (t , a) = p in (b , t) , a)
                                                (snocᵗ-proj-inj {T = T b} (t , a))

_++_ : (T : Tel ℓ) → (⟦ T ⟧ᵗ → Tel ℓ') → Tel (ℓ ⊔ ℓ')
_++_ []      U = U tt
_++_ (A ∷ T) U = A ∷ λ a → T a ++ λ t → U (a , t)

_^_ : Set → ℕ → Set
A ^ zero  = ⊤
A ^ suc n = A × (A ^ n)

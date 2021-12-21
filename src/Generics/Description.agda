{-# OPTIONS --without-K #-}

open import Prelude

module Generics.Description where

open import Generics.Telescope
open import Generics.Levels

private variable
    rb  : RecB
    cb  : ConB
    cbs : ConBs

module _ (I : Set ℓⁱ) where

  {-# NO_UNIVERSE_CHECK #-}
  data RecD : RecB → Set where
    ι : (i : I) → RecD []
    π : (A : Set ℓ) (D : A → RecD rb) → RecD (ℓ ∷ rb)
  syntax π A (λ x → R) = Π[ x ∶ A ] R
  
  {-# NO_UNIVERSE_CHECK #-}
  data ConD : ConB → Set where
    ι : (i : I) → ConD []
    σ : (A : Set ℓ) (D : A → ConD cb) → ConD (inl ℓ  ∷ cb)
    ρ : (D : RecD rb) (E : ConD cb)   → ConD (inr rb ∷ cb)
  syntax σ A (λ x → D) = Σ[ x ∶ A ] D

  {-# NO_UNIVERSE_CHECK #-}
  data ConDs : ConBs → Set where
    []  : ConDs []
    _∷_ : (D : ConD cb) (Ds : ConDs cbs) → ConDs (cb ∷ cbs)


{-# NO_UNIVERSE_CHECK #-}
record PDataD : Set where
  field
    alevel   : Level
    {plevel} : Level
    {ilevel} : Level
    {struct} : ConBs
  dlevel : Level
  dlevel = alevel ⊔ ilevel
  
  flevel : Level → Level
  flevel ℓ = maxMap max-π struct ⊔ maxMap max-σ struct ⊔
             maxMap (hasRec? ℓ) struct ⊔ hasCon? ilevel struct
  field
    level-pre-fixed-point : flevel dlevel ⊑ dlevel
    Param  : Tel plevel
    Index  : ⟦ Param ⟧ᵗ → Tel ilevel
    applyP : (p : ⟦ Param ⟧ᵗ) → ConDs ⟦ Index p ⟧ᵗ struct
open PDataD

{-# NO_UNIVERSE_CHECK #-}
record DataD : Set where
  field
    #levels : ℕ
  Levels : Set
  Levels = Level ^ #levels
  field
    applyL : Levels → PDataD
open DataD

module _ {I : Set ℓⁱ} where

  ⟦_⟧ʳ : RecD I rb → (I → Set ℓ) → Set (max-ℓ rb ⊔ ℓ)
  ⟦ ι i   ⟧ʳ X = X i
  ⟦ π A D ⟧ʳ X = (a : A) → ⟦ D a ⟧ʳ X

  ⟦_⟧ᶜ : ConD I cb → (I → Set ℓ) → (I → Set (max-π cb ⊔ max-σ cb ⊔ hasRec? ℓ cb ⊔ ℓⁱ))
  ⟦ ι i   ⟧ᶜ X j = i ≡ j
  ⟦ σ A D ⟧ᶜ X j = Σ A λ a → ⟦ D a ⟧ᶜ X j
  ⟦ ρ D E ⟧ᶜ X j = Σ (⟦ D ⟧ʳ X) λ _ → ⟦ E ⟧ᶜ X j

  ⟦_⟧ᶜˢ : ConDs I cbs → (I → Set ℓ) → (I → Set (maxMap max-π cbs ⊔ maxMap max-σ cbs ⊔
                                                maxMap (hasRec? ℓ) cbs ⊔ hasCon? ℓⁱ cbs))
  ⟦ []     ⟧ᶜˢ X i = ⊥
  ⟦ D ∷ Ds ⟧ᶜˢ X i = ⟦ D ⟧ᶜ X i ⊎ ⟦ Ds ⟧ᶜˢ X i

⟦_⟧ᵖᵈ : (D : PDataD) {p : ⟦ Param D ⟧ᵗ}
      → let I = ⟦ Index D p ⟧ᵗ in (I → Set ℓ) → (I → Set (flevel D ℓ))
⟦ D ⟧ᵖᵈ {p} = ⟦ PDataD.applyP D p ⟧ᶜˢ

⟦_⟧ᵈ : (D : DataD) {ℓs : Levels D} → let Dᵐ = applyL D ℓs in
       {p : ⟦ Param Dᵐ ⟧ᵗ}
     → let I = ⟦ Index Dᵐ p ⟧ᵗ in (I → Set ℓ) → (I → Set (flevel Dᵐ ℓ))
⟦ D ⟧ᵈ {ℓs} = ⟦ applyL D ℓs ⟧ᵖᵈ

fmapʳ : {I : Set ℓⁱ} (D : RecD I rb) {X : I → Set ℓˣ} {Y : I → Set ℓʸ}
      → ({i : I} → X i → Y i) → ⟦ D ⟧ʳ X → ⟦ D ⟧ʳ Y
fmapʳ (ι i  ) f x  = f x
fmapʳ (π A D) f xs = λ a → fmapʳ (D a) f (xs a)

fmapᶜ : {I : Set ℓⁱ} (D : ConD I cb) {X : I → Set ℓˣ} {Y : I → Set ℓʸ}
      → ({i : I} → X i → Y i) → {i : I} → ⟦ D ⟧ᶜ X i → ⟦ D ⟧ᶜ Y i
fmapᶜ (ι i  ) f eq       = eq
fmapᶜ (σ A D) f (a , xs) = a , fmapᶜ (D a) f xs
fmapᶜ (ρ D E) f (x , xs) = fmapʳ D f x , fmapᶜ E f xs

fmapᶜˢ : {I : Set ℓ} (Ds : ConDs I cbs) {X : I → Set ℓˣ} {Y : I → Set ℓʸ}
       → ({i : I} → X i → Y i) → {i : I} → ⟦ Ds ⟧ᶜˢ X i → ⟦ Ds ⟧ᶜˢ Y i
fmapᶜˢ (D ∷ Ds) f (inl xs) = inl (fmapᶜ  D  f xs)
fmapᶜˢ (D ∷ Ds) f (inr xs) = inr (fmapᶜˢ Ds f xs)

fmapᵖᵈ : (D : PDataD) {p : ⟦ Param D ⟧ᵗ} → let I = ⟦ Index D p ⟧ᵗ in
         {X : I → Set ℓˣ} {Y : I → Set ℓʸ}
       → ({i : I} → X i → Y i) → {i : I} → ⟦ D ⟧ᵖᵈ X i → ⟦ D ⟧ᵖᵈ Y i
fmapᵖᵈ D {p} = fmapᶜˢ (PDataD.applyP D p)

fmapᵈ : (D : DataD) {ℓs : Levels D} → let Dᵐ = applyL D ℓs in
        {p : ⟦ Param Dᵐ ⟧ᵗ} → let I = ⟦ Index Dᵐ p ⟧ᵗ in
        {X : I → Set ℓˣ} {Y : I → Set ℓʸ}
      → ({i : I} → X i → Y i) → {i : I} → ⟦ D ⟧ᵈ X i → ⟦ D ⟧ᵈ Y i
fmapᵈ D {ℓs} = fmapᵖᵈ (applyL D ℓs)

module DFunctor {I : Set ℓⁱ} {J : Set ℓʲ} (f : I → J) where

  imapʳ : RecD I rb → RecD J rb
  imapʳ (ι i  ) = ι (f i)
  imapʳ (π A D) = π A λ a → imapʳ (D a)

  imapᶜ : ConD I cb → ConD J cb
  imapᶜ (ι i  ) = ι (f i)
  imapᶜ (σ A D) = σ A λ a → imapᶜ (D a)
  imapᶜ (ρ D E) = ρ (imapʳ D) (imapᶜ E)

  imapᶜˢ : ConDs I cbs → ConDs J cbs
  imapᶜˢ []       = []
  imapᶜˢ (D ∷ Ds) = imapᶜ D ∷ imapᶜˢ Ds

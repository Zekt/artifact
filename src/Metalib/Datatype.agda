{-# OPTIONS --without-K #-}

open import Prelude
  hiding (T)

module Metalib.Datatype where

open import Utils.Reflection
open import Utils.Error          as Err

open import Generics.Telescope   as Desc
open import Generics.Levels      as Desc
open import Generics.Description as Desc

open import Metalib.Telescope as Tel

private
  variable
    rb  : RecB
    cb  : ConB
    cbs : ConBs
    T   : Tel ℓ
  
  pattern `ιʳ x  = con₁ (quote RecD.ι) x
  pattern `ιᶜ x  = con₁ (quote ConD.ι) x
  pattern `π x y = con₂ (quote π) x y
  pattern `σ x y = con₂ (quote σ) x y
  pattern `ρ x y = con₂ (quote ρ) x y

  pattern `refl          = con (quote _≡_.refl) (hArg `lzero ∷ hArg `Level ∷ hArg unknown ∷ [])
  pattern pat₁lam₀ Γ p t = pat-lam₀ [ Γ ⊢ [ p ] `= t ]

  pattern `datad x y        = con₂ (quote datad) x y
  pattern `pdatad x y z u v = con₅ (quote pdatad) x y z u v

  -- Translate the semantics of an object-level telescope to a context
  idxToArgs : ⟦ T ⟧ᵗ → TC Context
  idxToArgs {T = []}    tt      = ⦇ [] ⦈
  idxToArgs {T = _ ∷ _} (x , Γ) = ⦇ (vArg <$> quoteTC x) ∷ (idxToArgs Γ) ⦈
    
  -- ... and back
  argsToIdx : Context → Term
  argsToIdx []       = `tt
  argsToIdx (x ∷ xs) = (unArg x) `, argsToIdx xs

  to`ConDs : Terms → Term
  to`ConDs = foldr (con₀ (quote ConDs.[])) (con₂ (quote ConDs._∷_))

  Σpat : Telescope → Pattern
  Σpat = snd ∘ foldr (0 , `tt) λ where
    _ (n , p) → suc n , (var n `, p)

  patLam : Telescope → Term → Term
  patLam tel body = pat₁lam₀ tel (vArg (Σpat tel)) body

  -- Some functions to parse the type signature of a datatype
  splitLevels : Telescope → (ℕ × Telescope)
  splitLevels []                      = 0 , []
  splitLevels t@((_ , arg _ a) ∷ tel) = if a == `Level
    then bimap suc id (splitLevels tel)
    else 0 , t
    
  -- The fully applied datatype 
  typeOfData : (d : Name) (pars : ℕ)  → ⟦ T ⟧ᵗ → TC Type 
  typeOfData d pars `x = do
    args ← (vUnknowns pars <>_) <$> idxToArgs `x
    return $ def d args

  endsIn : Type → Name → Bool
  endsIn (def f _)       u = f == u
  endsIn (`Π[ _ ∶ _ ] b) u = endsIn b u
  endsIn _               u = false
------------------------------------------------------------------------
-- Translate an object-level datatype description `DataD` to the meta-level
-- declaration 
module _ {T : Tel ℓ} (`A : ⟦ T ⟧ᵗ → TC Type) where
  RecDToType : (R : RecD ⟦ T ⟧ᵗ rb) → TC Type
  RecDToType (ι i) = `A i
  RecDToType (π A D) = extendContextT visible-relevant-ω A λ `A x →
      vΠ[ `A ]_ <$> RecDToType (D x)
  ConDToType : (D : ConD ⟦ T ⟧ᵗ cb) → TC Type
  ConDToType (ι i) = `A i
  ConDToType (σ A D) = extendContextT visible-relevant-ω A λ `A x →
    vΠ[ `A ]_ <$>  ConDToType (D x)
  ConDToType (ρ R D) = do
    `R ← RecDToType R
    extendContext (vArg (quoteTerm ⊤)) do
      vΠ[ `R ]_ <$> ConDToType D
  ConDsToTypes : (Ds : ConDs ⟦ T ⟧ᵗ cbs) → TC (List Type)
  ConDsToTypes []       = return []
  ConDsToTypes (D ∷ Ds) = ⦇ ConDToType D ∷ ConDsToTypes Ds ⦈

getCons : Name → (pars : ℕ) → (`Param : Telescope) → PDataD → TC (List Type)
getCons d pars `Param Dᵖ = extendContextTs Param λ ⟦Ps⟧ →
  map (prefixToType `Param) <$> ConDsToTypes (typeOfData d pars) (applyP ⟦Ps⟧)
  where open PDataD Dᵖ
{-# INLINE getCons #-}

getSignature : PDataD → TC (ℕ × Telescope × Type)
getSignature Dᵖ = do
  pars  , `Param ← fromTel Param
  dT             ← fromTelType (Param ++ Index) (Set dlevel)
  return $ pars , `Param , dT
  where open PDataD Dᵖ

defineByDataD : DataD → Name → List Name → TC _
defineByDataD dataD dataN conNs = extendContextℓs #levels λ ℓs → do
  let `Levels = levels #levels
  let Dᵖ      = applyL ℓs
  pars , `Param , dT ← getSignature Dᵖ
  declareData dataN (#levels + pars) (prefixToType `Levels dT)

  conTs ← map (prefixToType `Levels) <$> getCons dataN pars `Param Dᵖ
  defineData dataN (zip conNs conTs)
  where open DataD dataD

------------------------------------------------------------------------
-- Translate an meta-level datatype declaration to the its object-level
-- description

module _ (dataName : Name) (#levels : ℕ) (parLen : ℕ) where
  -- `pars` is the total number of parameters
  pars : ℕ
  pars = #levels + parLen 
  
  telescopeToRecD : Telescope → Type → TC Term
  telescopeToRecD ((s , arg _ `x) ∷ `tel) end = do
    rec ← telescopeToRecD `tel end
    return $ `π `x (vLam (abs s rec))
  telescopeToRecD [] (def f args) = if f == dataName
    then return $ `ιʳ (argsToIdx $ drop pars args)
    else Err.notEndIn dataName
  telescopeToRecD [] _ = Err.notEndIn dataName

  telescopeToConD : Telescope → Type → TC Term
  telescopeToConD ((s , (arg _ `x)) ∷ `tel) end = if endsIn `x dataName
    then (do 
      recd ← uncurry telescopeToRecD (⇑ `x)
      cond ← telescopeToConD `tel end
    -- Indices in recursion in Description is different from those in native constructors! Should strengthen by one instead of abstracting.
      return $ `ρ recd (strengthen 0 1 cond)
    ) else (do
      cond ← telescopeToConD `tel end
      return $ `σ `x  (vLam (abs s cond))
    )
  telescopeToConD [] (def f args) = if f == dataName
    then (return $ `ιᶜ (argsToIdx $ drop pars args))
    else (Err.notEndIn dataName)
  telescopeToConD [] _ = Err.notEndIn dataName

  describeConstructor : Name → TC Term
  describeConstructor conName = do
    conType ← getType conName
    let (tel , end) = (⇑ conType) ⦂ Telescope × Type
    telescopeToConD (drop pars tel) end

describeData : ℕ → Name → List Name → TC Term
describeData parLen dataName conNames = do
    dataType ← getType dataName

    let (tel     , end) = (⇑ dataType) ⦂ Telescope × Type
        (#levels , tel) = splitLevels tel
        (par     , idx) = splitAcc [] tel parLen
    conDefs  ← mapM (describeConstructor dataName #levels parLen) conNames
    `ℓ       ← extractLevel end
    `#levels ← quoteTC! #levels
    
    let applyBody = to`ConDs conDefs
        lenTel    = length tel
        `lamℓ     = strengthen lenTel lenTel `ℓ
        `lampar   = strengthen lenTel lenTel $ to`Tel par
        ℓtel      = duplicate #levels ("_" , vArg `Level)
    return $ `datad `#levels
      (patLam ℓtel (`pdatad `lamℓ `refl `lampar (patLam par (to`Tel idx)) (patLam par applyBody)))
  where
    splitAcc : Telescope → Telescope → ℕ → (Telescope × Telescope)
    splitAcc tel₁ []   n = tel₁ , []
    splitAcc tel₁ tel₂ 0 = tel₁ , tel₂
    splitAcc tel₁ (x ∷ tel₂) (suc n) = splitAcc (tel₁ <> [ x ]) tel₂ n

    extractLevel : Type → TC Term
    extractLevel (agda-sort (set t)) = return t
    extractLevel (`Set n) = quoteTC (fromℕ n)
    extractLevel (def (quote Set) []) = return (quoteTerm lzero)
    extractLevel (def (quote Set) [ arg _ x ]) = return x
    extractLevel t = quoteTC t >>= λ t →
                     typeError [ strErr $ showTerm t <> " level error!" ]

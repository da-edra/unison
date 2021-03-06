module Unison.Typechecker.TypeLookup where

import Control.Applicative ((<|>))
import Data.Map (Map)
import Unison.Reference (Reference)
import Unison.Referent (Referent)
import Unison.Type (AnnotatedType)
import Unison.Var (Var)
import qualified Data.Map as Map
import qualified Unison.ConstructorType as CT
import qualified Unison.DataDeclaration as DD
import qualified Unison.Referent as Referent

type Type v a = AnnotatedType v a
type DataDeclaration v a = DD.DataDeclaration' v a
type EffectDeclaration v a = DD.EffectDeclaration' v a
-- todo: move to DataDeclaration.hs
type Decl v a = Either (EffectDeclaration v a) (DataDeclaration v a)

-- Used for typechecking.
data TypeLookup v a =
  TypeLookup { typeOfTerms :: Map Reference (Type v a)
             , dataDecls :: Map Reference (DataDeclaration v a)
             , effectDecls :: Map Reference (EffectDeclaration v a) }
  deriving Show

builtinTypeLookup :: Var v => TypeLookup v ()
builtinTypeLookup = TypeLookup mempty decls mempty where
  decls = Map.fromList [ (r, dd) | (_, r, dd) <- DD.builtinDataDecls ]

typeOfReferent :: TypeLookup v a -> Referent -> Maybe (Type v a)
typeOfReferent tl r = case r of
  Referent.Ref r -> typeOfTerm tl r
  Referent.Con r cid -> typeOfDataConstructor tl r cid <|>
                        typeOfEffectConstructor tl r cid

constructorType :: TypeLookup v a -> Reference -> Maybe CT.ConstructorType
constructorType tl r =
  (const CT.Data <$> Map.lookup r (dataDecls tl)) <|>
  (const CT.Effect <$> Map.lookup r (effectDecls tl))

typeOfDataConstructor :: TypeLookup v a -> Reference -> Int -> Maybe (Type v a)
typeOfDataConstructor tl r cid = go =<< Map.lookup r (dataDecls tl)
  where go dd = DD.typeOfConstructor dd cid

typeOfEffectConstructor :: TypeLookup v a -> Reference -> Int -> Maybe (Type v a)
typeOfEffectConstructor tl r cid = go =<< Map.lookup r (effectDecls tl)
  where go dd = DD.typeOfConstructor (DD.toDataDecl dd) cid

typeOfTerm :: TypeLookup v a -> Reference -> Maybe (Type v a)
typeOfTerm tl r = Map.lookup r (typeOfTerms tl)

typeOfTerm' :: TypeLookup v a -> Reference -> Either Reference (Type v a)
typeOfTerm' tl r = case Map.lookup r (typeOfTerms tl) of
  Nothing -> Left r
  Just a -> Right a

instance Semigroup (TypeLookup v a) where (<>) = mappend

instance Monoid (TypeLookup v a) where
  mempty = TypeLookup mempty mempty mempty
  mappend (TypeLookup a b c) (TypeLookup a2 b2 c2) =
    TypeLookup (a <> a2) (b <> b2) (c <> c2)

instance Functor (TypeLookup v) where
  fmap f tl =
    TypeLookup
      (fmap f <$> typeOfTerms tl)
      (fmap f <$> dataDecls tl)
      (fmap f <$> effectDecls tl)

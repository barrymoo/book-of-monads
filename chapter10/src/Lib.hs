{-# LANGUAGE FlexibleContexts     #-}
{-# LANGUAGE TypeOperators        #-}
{-# LANGUAGE UndecidableInstances #-}

module Lib where

import           Control.Applicative
import           Control.Monad                  ( join )

newtype (f :.: g) a =
  Compose (f (g a))

instance (Functor f, Functor g) => Functor (f :.: g) where
  fmap f (Compose x) = Compose $ (fmap . fmap) f x

instance (Foldable (f :.: g), Traversable f, Traversable g) =>
         Traversable (f :.: g) where
  traverse f (Compose g) = Compose <$> (traverse . traverse) f g

instance (Applicative f, Applicative g) => Applicative (f :.: g) where
  pure = Compose . pure . pure
  -- f :: f (g (a -> b))
  -- x :: f (g (a))
  Compose f <*> Compose x = Compose $ (<*>) <$> f <*> x

instance (Alternative f, Alternative g) => Alternative (f :.: g) where
  empty = Compose empty
  Compose x <|> Compose y = Compose $ x <|> y

-- join :: m (m a) -> m a
-- join :: (f :.: g) ((f :.: g) a) -> (f :.: g) a
-- join :: f (g (f (g a))) -> f (g a)
-- Because f & g are interleaved we cannot freely compose monads

-- swap :: g (f a) -> f (g a)
-- If we can write this function there
-- is a distributive law for those types
-- e.g. Reader is distributive

swap :: (r -> s -> a) -> (s -> r -> a)
swap = flip

swapMaybe :: Monad m => Maybe (m a) -> m (Maybe a)
swapMaybe Nothing = pure Nothing
swapMaybe (Just ma) = Just <$> ma

newtype Writer w a =
  Writer
    { runWriter :: (a, w)
    }

newtype Reader r a =
  Reader
    { runReader :: r -> a
    }

-- Exercise 10.1
-- The complement to both of these functions are not possible to implement
-- because `(>>=)` works by flattening an `m (m a)` However, we need `(>>=)` to
-- create a result with `Reader,Writer` as the outer monad (which isn't
-- possible).
swapWriter :: Monad m => (Writer w :.: m) a -> (m :.: Writer w) a
swapWriter (Compose c) = Compose $
  let (ma, w) = runWriter c
   in ma >>= \a -> pure $ Writer (a, w)

swapReader :: Monad m => (m :.: Reader r) a -> (Reader r :.: m) a 
swapReader (Compose c) = Compose . Reader $
  \r ->
    c >>= \rra ->
      pure $ runReader rra r

newtype Listed m a =
  Listed
    { unListed :: [m a]
    } deriving Show

-- Exercise 10.2 - Write Functor and Applicative
-- for `Listed`
instance Functor m => Functor (Listed m) where
  fmap f (Listed xs) = Listed $ (fmap . fmap) f xs

instance Applicative m => Applicative (Listed m) where
  pure a = Listed [pure a]
  --Listed fab <*> Listed xs = Listed $ [mf <*> x | mf <- fab, x <- xs]
  Listed fab <*> Listed xs = Listed $ (<*>) <$> fab <*> xs

instance (Traversable m, Monad m) => Monad (Listed m) where
  Listed xs >>= f = Listed $ do
    x <- xs
    y <- mapM (unListed . f) x
    pure $ join y

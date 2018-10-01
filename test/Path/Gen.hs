{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TemplateHaskell #-}
module Path.Gen where

import           Data.Functor
import           Prelude

import           Path
import           Path.Internal

import qualified System.FilePath as FilePath

import           Data.Maybe (mapMaybe, isJust)
import           Data.List (isInfixOf)
import           Data.Validity
import           Data.GenValidity

import           Test.QuickCheck


instance Validity (Path Abs File) where
  isValid p@(Path fp)
    =  FilePath.isAbsolute fp
    && not (FilePath.hasTrailingPathSeparator fp)
    && FilePath.isValid fp
    && not (hasParentDir fp)
    && (parseAbsFile fp == Just p)

instance Validity (Path Rel File) where
  isValid p@(Path fp)
    =  FilePath.isRelative fp
    && not (FilePath.hasTrailingPathSeparator fp)
    && FilePath.isValid fp
    && fp /= "."
    && not (hasParentDir fp)
    && (parseRelFile fp == Just p)

instance Validity (Path Abs Dir) where
  isValid p@(Path fp)
    =  FilePath.isAbsolute fp
    && FilePath.hasTrailingPathSeparator fp
    && FilePath.isValid fp
    && not (hasParentDir fp)
    && (parseAbsDir fp == Just p)

instance Validity (Path Rel Dir) where
  isValid p =
    FilePath.isRelative fp
    && FilePath.hasTrailingPathSeparator fp
    && FilePath.isValid fp
    && not (hasParentDir fp)
    && (parseRelDir fp == Just p)
    where fp = toFilePath p

instance GenUnchecked (Path Abs File) where
  genUnchecked = Path <$> genFilePath

instance GenValid (Path Abs File)

instance GenUnchecked (Path Rel File) where
  genUnchecked = Path <$> genFilePath

instance GenValid (Path Rel File)

instance GenUnchecked (Path Abs Dir) where
  genUnchecked = Path <$> genFilePath

instance GenValid (Path Abs Dir)

instance GenUnchecked (Path Rel Dir) where
  genUnchecked = Path <$> genFilePath

instance GenValid (Path Rel Dir)

data Extension = Extension String deriving Show

instance Validity Extension where
  isValid (Extension ext) = isJust $ addExtension ext $(mkRelFile "x")

instance GenUnchecked Extension where
  genUnchecked = Extension <$> genFilePath

instance GenValid Extension

-- | Generates 'FilePath's with a high occurence of @'.'@, @'\/'@ and
-- @'\\'@ characters. The resulting 'FilePath's are not guaranteed to
-- be valid.
genFilePath :: Gen FilePath
genFilePath = listOf genPathyChar

genPathyChar :: Gen Char
genPathyChar = frequency [(2, arbitrary), (1, elements "./\\")]

shrinkValidAbsFile :: Path Abs File -> [Path Abs File]
shrinkValidAbsFile = shrinkValidWith parseAbsFile

shrinkValidAbsDir :: Path Abs Dir -> [Path Abs Dir]
shrinkValidAbsDir = shrinkValidWith parseAbsDir

shrinkValidRelFile :: Path Rel File -> [Path Rel File]
shrinkValidRelFile = shrinkValidWith parseRelFile

shrinkValidRelDir :: Path Rel Dir -> [Path Rel Dir]
shrinkValidRelDir (Path []) = []
shrinkValidRelDir p = shrinkValidWith parseRelDir p

shrinkValidWith :: (FilePath -> Maybe (Path a b)) -> Path a b -> [Path a b]
shrinkValidWith fun (Path s) = mapMaybe fun $ shrink s

shrinkValidExtension :: Extension -> [Extension]
shrinkValidExtension (Extension s) =
    map (Extension . drop 1 . toFilePath) $
        mapMaybe (flip addExtension $(mkRelFile "x")) (shrink s)

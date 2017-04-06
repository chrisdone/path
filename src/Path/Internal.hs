{-# LANGUAGE CPP                #-}
{-# LANGUAGE DeriveDataTypeable #-}

-- | Internal types and functions.

module Path.Internal
  ( Path(..)
  , hasParentDir
  , curDirNormalizedFP
  , toFilePath
  )
  where

import Control.DeepSeq (NFData (..))
import Data.Aeson (ToJSON (..))
import Data.Data
import Data.Hashable
import Data.List
import qualified System.FilePath as FilePath

-- | Path of some base and type.
--
-- The type variables are:
--
--   * @b@ — base, the base location of the path; absolute or relative.
--   * @t@ — type, whether file or directory.
--
-- Internally is a string. The string can be of two formats only:
--
-- 1. File format: @file.txt@, @foo\/bar.txt@, @\/foo\/bar.txt@
-- 2. Directory format: @foo\/@, @\/foo\/bar\/@
--
-- All directories end in a trailing separator. There are no duplicate
-- path separators @\/\/@, no @..@, no @.\/@, no @~\/@, etc.
newtype Path b t = Path FilePath
  deriving (Typeable)

-- | String equality.
--
-- The following property holds:
--
-- @show x == show y ≡ x == y@
instance Eq (Path b t) where
  (==) (Path x) (Path y) = x == y

-- | String ordering.
--
-- The following property holds:
--
-- @show x \`compare\` show y ≡ x \`compare\` y@
instance Ord (Path b t) where
  compare (Path x) (Path y) = compare x y

-- | Normalized file path for the current directory
curDirNormalizedFP :: FilePath
curDirNormalizedFP = '.' : [FilePath.pathSeparator]

-- | Convert to a 'FilePath' type.
--
-- All directories have a trailing slash, so if you want no trailing
-- slash, you can use 'System.FilePath.dropTrailingPathSeparator' from
-- the filepath package.
toFilePath :: Path b t -> FilePath
toFilePath (Path []) = curDirNormalizedFP
toFilePath (Path x)  = x

-- | Same as 'show . Path.toFilePath'.
--
-- The following property holds:
--
-- @x == y ≡ show x == show y@
instance Show (Path b t) where
  show = show . toFilePath

instance NFData (Path b t) where
  rnf (Path x) = rnf x

instance ToJSON (Path b t) where
  toJSON = toJSON . toFilePath
  {-# INLINE toJSON #-}
#if MIN_VERSION_aeson(0,10,0)
  toEncoding = toEncoding . toFilePath
  {-# INLINE toEncoding #-}
#endif

instance Hashable (Path b t) where
  -- A "." is represented as an empty string ("") internally. Hashing ""
  -- results in a hash that is the same as the salt. To produce a more
  -- reasonable hash we use "toFilePath" before hashing so that a "" gets
  -- converted back to a ".".
  hashWithSalt n path = hashWithSalt n (toFilePath path)

-- | Helper function: check if the filepath has any parent directories in it.
-- This handles the logic of checking for different path separators on Windows.
hasParentDir :: FilePath -> Bool
hasParentDir filepath' =
     (filepath' == "..") ||
     ("/.." `isSuffixOf` filepath) ||
     ("/../" `isInfixOf` filepath) ||
     ("../" `isPrefixOf` filepath)
  where
    filepath =
        case FilePath.pathSeparator of
            '/' -> filepath'
            x   -> map (\y -> if x == y then '/' else y) filepath'

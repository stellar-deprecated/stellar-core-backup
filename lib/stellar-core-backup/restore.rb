require "stellar-core-backup/version"
require "contracts"
require "fileutils"
require "pg"

#TODO @scott ?
module StellarCoreBackup
  module Restore
    autoload :Database, "stellar-core-backup/restore/database"
    autoload :Filesystem, "stellar-core-backup/restore/filesystem"
  end
end

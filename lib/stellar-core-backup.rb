require "stellar-core-backup/version"
require "contracts"
require "fileutils"
require "pg"

module StellarCoreBackup
  autoload :Cmd, "stellar-core-backup/cmd"
  autoload :CmdResult, "stellar-core-backup/cmd_result"
  autoload :Config, "stellar-core-backup/config"
  autoload :Database, "stellar-core-backup/database"
  autoload :Filesystem, "stellar-core-backup/filesystem"
  autoload :Job, "stellar-core-backup/job"
  autoload :S3, "stellar-core-backup/s3"
  autoload :Tar, "stellar-core-backup/tar"
  autoload :Utils, "stellar-core-backup/utils"

  module Restore
    autoload :Database, "stellar-core-backup/restore/database"
    autoload :Filesystem, "stellar-core-backup/restore/filesystem"
  end
end

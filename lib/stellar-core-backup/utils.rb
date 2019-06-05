require 'fileutils'

module StellarCoreBackup
  class Utils
    include Contracts

    Contract StellarCoreBackup::Config => Contracts::Any
    def initialize(config)
      @config       = config
      @working_dir  = StellarCoreBackup::Utils.create_working_dir(@config.get('working_dir'))
      @db_restore   = StellarCoreBackup::Restore::Database.new(@config)
      @fs_restore   = StellarCoreBackup::Restore::Filesystem.new(@config)
    end

    Contract String => String
    def self.create_working_dir(dir)
      working_dir = dir + "/#{Process.pid}"
      unless Dir.exists?(working_dir) then
        Dir.mkdir working_dir
      end
      return working_dir
    end

    Contract String => nil
    def self.remove_working_dir(working_dir)
      if Dir.exists?(working_dir) then
        Dir.rmdir working_dir + "/#{Process.pid}"
      end
    end

    Contract String => String
    def self.create_backup_dir(dir)
      unless Dir.exists?(dir) then
        Dir.mkdir dir
      end
      return dir
    end

    Contract String, String => String
    def self.create_hash_file(working_dir)
      puts 'info: creating file of backup file hashes'
      Dir.chdir(working_dir)
      `find . -type f ! -name SHA256SUMS | xargs sha256sum > SHA256SUMS`
    end

    Contract String, String => String
    def self.sign_hash_file(working_dir)
      puts 'info: signing hash file'
      Dir.chdir(working_dir)
      `gpg --detach-sign SHA256SUMS`
    end

    Contract String, String => String
    def self.create_backup_tar(working_dir, backup_dir)
      puts 'info: creating backup tarball'
      tar_file = "#{backup_dir}/core-backup-#{Time.now.to_i}.tar"
      Dir.chdir(working_dir)
      # archive the working directory
      StellarCoreBackup::Tar.pack(tar_file, '.')
      return tar_file
    end

    Contract String, String => String
    def self.verify_hash_file(working_dir)
      puts 'info: verifying sha256sums file'
      Dir.chdir(working_dir)
      `gpg --verify SHA256SUMS.sig SHA256SUMS`
    end

    Contract String, String => String
    def self.verify_sha_file_content(working_dir)
      puts 'info: verifying sha256sums file'
      Dir.chdir(working_dir)
      `sha256sum --status --strict -c SHA256SUMS`
    end

#    Contract String => nil
#    def restore(backup_archive)
#      @fs_restore.restore(backup_archive)
#      @db_restore.restore()
#    end

    Contract String => Bool
    def self.cleanup(working_dir)
      if FileUtils.remove_dir(working_dir)
        puts 'info: cleaning up workspace'
        return true
      else
        return false
      end
    end

    # check we have read permissions
    Contract String => Bool
    def self.readable?(file)
      if File.readable?(file) then
        puts "info: #{file} readable"
        return true
      else
        puts "error: cannot read #{file}"
        raise Errno::EACCES
      end
    end

    # check we have write permissions
    Contract String => Bool
    def self.writable?(file)
      if File.writable?(file) then
        puts "info: #{file} writeable"
        return true
      else
        puts "error: cannot write to #{file}"
        raise Errno::EACCES
      end
    end

  end
end

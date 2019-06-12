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
    def self.create_backup_tar(working_dir, backup_dir)
      puts 'info: creating backup tarball'
      tar_file = "#{backup_dir}/core-backup-#{Time.now.to_i}.tar"
      Dir.chdir(working_dir)
      # archive the working directory
      StellarCoreBackup::Tar.pack(tar_file, '.')
      return tar_file
    end

    Contract String => nil
    def extract_backup(backup_archive)
      # extract the backup archive into the working directory
      StellarCoreBackup::Tar.unpack(backup_archive, @working_dir)
      return
    end

#    Contract String => nil
#    def restore(backup_archive)
#      @fs_restore.restore(backup_archive)
#      @db_restore.restore()
#    end

    Contract String => Bool
    def self.cleanbucket(bucket_dir)
      if FileUtils.remove(Dir.glob(bucket_dir+'/*')) then
        puts 'info: cleaning up workspace'
        return true
      else
        return false
      end
    end

    Contract String => Bool
    def self.cleanup(working_dir)
      if FileUtils.remove_dir(working_dir) then
        puts 'info: cleaning up workspace'
        return true
      else
        return false
      end
    end

    Contract String, String => Bool
    def self.confirm_shasums_definitive(working_dir, backup_archive)

      # create an array of filesunpacked into the working_dir
      Dir.chdir(working_dir)
      files_present=Dir.glob('./**/*')

      # remove directories and shasum details from file array
      files_present.delete('./'+File.basename(backup_archive))
      files_present.delete('./core-db')
      files_present.delete('./SHA256SUMS')
      files_present.delete('./SHA256SUMS.sig')

      # now delete the file names in the shasums file from the array
      # we are expecting an array of zero length after this process
      File.open("SHA256SUMS").each { |sha_file| files_present.delete(sha_file.split(' ')[1].chomp) }
      if files_present.none? then
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

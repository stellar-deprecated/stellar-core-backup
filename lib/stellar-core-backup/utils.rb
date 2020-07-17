require 'fileutils'
require 'net/http'
require 'json'
require 'time'


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

    # return number of available cores
    Contract nil => Integer
    def self.num_cores?()
      require 'etc'
      return Etc.nprocessors
    end

    # check stellar-core status
    Contract StellarCoreBackup::Config => Bool
    def self.core_healthy?(config)
      port = get_admin_port(config.get('core_config'))
      url = "http://127.0.0.1:%s/info" % port
      uri = URI(url)
      begin
        response = Net::HTTP.get(uri)
        state = JSON.parse(response)['info']['state']
        if state == 'Synced!' then
          puts "info: stellar-core up and synced"
          return true
        else
          puts "error: stellar-core status is: %s" % state
          return false
        end
      rescue
        puts "info: stellar-core down or not synced"
        return false
      end
    end

    private
    Contract String => String
    def self.get_admin_port(config)
      File.open(config,'r') do |fd|
        fd.each_line do |line|
          if (line[/^HTTP_PORT=/]) then
            port = /^HTTP_PORT=(.*)/.match(line).captures[0]
            return port
          end
        end
      end
    end

    # Publishes metric to pushgateway
    # if no value provided current epoch timestamp will be used
    Contract Any, String, Any => Bool
    def self.push_metric(url, metric, value=nil)
      if url.nil? then
        # No url means pushgateway URL is not configured
        return false
      end

      if value.nil? then
          value = Time.now.to_i
      end

      uri = URI(url)
      req = Net::HTTP::Post.new(uri.request_uri)
      req.body = "%s %i\n" % [metric, value]
      http = Net::HTTP.new(uri.host, uri.port)
      http.request(req)
      return true
    end

  end
end

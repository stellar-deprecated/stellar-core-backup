require 'minitar'

module StellarCoreBackup::Restore
  class Filesystem < ::StellarCoreBackup::Filesystem
    include Contracts

    class DataDirNotEmpty < StandardError ; end

    attr_reader :core_data_dir

    Contract StellarCoreBackup::Config => Contracts::Any
    def initialize(config)
      @config         = config
      @working_dir    = StellarCoreBackup::Utils.create_working_dir(@config.get('working_dir'))
      @core_data_dir  = get_core_data_dir(@config.get('core_config'))
    end

    public
    Contract String => nil
    def restore(backup_archive)
      unpack(backup_archive, @working_dir)
      puts "info: stellar-core buckets restored" if unpack("#{@working_dir}/core-fs.tar", @core_data_dir)
    end

    Contract nil => Bool
    def core_data_dir_empty?()
      # checks fs and asks user to remove fs manually if fs is already in place.
      if (Dir.entries(@core_data_dir) - %w{ . .. }).empty? then
        return true
      else
        puts "error: #{@core_data_dir} is not empty, you can only restore to an empty data directory"
        raise DataDirNotEmpty
      end
    end

    private
    Contract String, String => nil
    def unpack(archive, unpack_to)
      if StellarCoreBackup::Utils.writable?(unpack_to) then
        # unpack the tar ball
        puts "info: unpacking #{archive} to #{unpack_to}"
        Minitar.unpack(archive, unpack_to)
      end
    end

  end
end

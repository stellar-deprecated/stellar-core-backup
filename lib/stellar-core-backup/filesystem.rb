module StellarCoreBackup
  class Filesystem
    include Contracts

    class ReadError < StandardError ; end

    attr_reader :core_data_dir

    Contract StellarCoreBackup::Config => Contracts::Any
    def initialize(config)
      @config         = config
      @working_dir    = StellarCoreBackup::Utils.create_working_dir(@config.get('working_dir'))
      @core_data_dir  = get_core_data_dir(@config.get('core_config'))
    end

    public
    def backup()
      create_core_data_tar()
    end

    private
    #Contract nil, StellarCoreBackup::CmdResult
    def create_core_data_tar()
      if core_data_readable?() then
        # create the tar balls
        puts "info: creating filesystem backup"
        Dir.chdir(@core_data_dir)
        StellarCoreBackup::Tar.pack("#{@working_dir}/core-fs.tar", '.')
        Dir.chdir(@working_dir)
      end
    end

    private
    # TODO: replace with Utils.readable ?
    # check we have read access to the stellar-core data
    Contract nil => Contracts::Any
    def core_data_readable?()
      if File.readable?("#{@core_data_dir}/stellar-core.lock") then
        puts "info: processing #{@core_data_dir}"
        return true
      else
        puts "error: can not access #{@core_data_dir}"
        raise ReadError
      end
    end

    private
    Contract String => String
    def get_core_data_dir(config)
      File.open(config,'r') do |fd|
        fd.each_line do |line|
          if (line[/^BUCKET_DIR_PATH=/]) then
            # "postgresql://dbname=stellar user=stellar"
            core_data_dir = /^BUCKET_DIR_PATH="(.*)"$/.match(line).captures[0]
            return core_data_dir
          end
        end
      end
    end

  end
end

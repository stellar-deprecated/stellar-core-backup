require 'fileutils'

module StellarCoreBackup
  class Tar
    include Contracts

    Contract String, String => String
    def self.pack(archive, directory)
      if StellarCoreBackup::Utils.readable?(directory) then
        # archive directory
        puts "info: packing #{directory} in #{archive}"
        %x{/bin/tar --create --file=#{archive} #{directory}}
        if $?.exitstatus == 0 then
          puts "info: #{archive} created"
          return archive
        else
          raise StandardError
        end
      end
    end

    Contract String, String => String
    def self.unpack(archive, destination)
      if StellarCoreBackup::Utils.writable?(destination) then
        # extract archive in destination directory
        puts "info: unpacking #{archive} in #{destination}"
        %x{/bin/tar --extract --file=#{archive} --directory=#{destination}}
        if $?.exitstatus == 0 then
          puts "info: #{archive} unpacked in #{destination}"
          return destination
        else
          raise StandardError
        end
      end
    end
  end
end

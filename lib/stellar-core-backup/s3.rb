require 'aws-sdk-s3'

module StellarCoreBackup
  class S3
    include Contracts

    Contract StellarCoreBackup::Config => Contracts::Any
    def initialize(config)
      @config = config
      @working_dir  = StellarCoreBackup::Utils.create_working_dir(@config.get('working_dir'))
      @s3_bucket = @config.get('s3_bucket')
      @s3_path = @config.get('s3_path')
      begin
        # TODO: move region to configuration file ?
        @s3_client = Aws::S3::Client.new(region: 'us-east-1')
        @s3_resource = Aws::S3::Resource.new(client: @s3_client)
      rescue Aws::S3::Errors::ServiceError => e
        puts "info: error connecting to s3"
        puts e
      end
    end

    def push(file)
      begin
        upload = @s3_resource.bucket(@s3_bucket).object("#{@s3_path}/#{File.basename(file)}")
        if upload.upload_file(file) then
          puts "info: pushed #{file} to s3 (#{@s3_bucket})"
        else
          puts "error: upload to s3 failed"
        end
      rescue Aws::S3::Errors::ServiceError => e
        puts "info: error pushing #{file} to s3 (#{@s3_bucket})"
        puts e
      end
    end

    # fetches a backup tar file from s3, places in working dir
    def get(file)
      local_copy = "#{@working_dir}/#{File.basename(file)}"
      begin
        download = @s3_resource.bucket(@s3_bucket).object(file)
        if download.download_file(local_copy) then
          puts "info: fetched #{file} from s3 (#{@s3_bucket})"
          return local_copy
        else
          puts "error: download from s3 failed"
        end
      rescue Aws::S3::Errors::ServiceError => e
        puts "info: error downloading #{file} from s3 (#{@s3_bucket})"
        puts e
      end
    end

    # fetch list of all s3 objects, sort and return latest/last
#    def latest(listlen)
#      @s3_client.list_objects_v2({bucket: @s3_bucket, prefix: @s3_path+'/core-backup-'}).contents.map{|o| o.key}.sort{|a,b| a.gsub(/(\d+)/,'\1') <=> b.gsub(/(\d+)/,'\1')}.last(listlen)
#    end

    def latest(listlen)
      begin
        @s3_client.list_objects_v2({bucket: @s3_bucket, prefix: @s3_path+'/core-backup-'}).contents.map{|o| o.key}.sort{|a,b| a.gsub(/(\d+)/,'\1') <=> b.gsub(/(\d+)/,'\1')}.last(listlen)
      rescue Aws::S3::Errors::ServiceError => e
        puts "info: error listing s3 (#{@s3_bucket})"
        puts e
      end
    end

  end
end

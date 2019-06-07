task :build do
  system "gem build stellar-core-backup.gemspec"
end

task :install => :build do
  system "gem install --local --user-install stellar-core-backup"
  system "sudo gem install --local stellar-core-backup"
end

